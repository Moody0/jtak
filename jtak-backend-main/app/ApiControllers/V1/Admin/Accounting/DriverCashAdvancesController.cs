using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Threading.Tasks;
using App.ApiModels;
using App.Extensions;
using App.Shared.Entities;
using App.Shared.Entities.Enums;
using App.Shared.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using Modules.Accounting.Services;
using OpenIddict.Validation.AspNetCore;

namespace App.ApiControllers.V1.Admin.Accounting
{
    [Route("api/v{version:apiVersion}/Admin/DriverCashAdvances")]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme,
        Policy = nameof(AppPermissionKey.AdminPermission))]
    public class DriverCashAdvancesController : ControllerBase
    {
        private const string Currency = "SYP";
        private const string ReferenceType = "CaptainCashAdvance";
        private readonly AccountingDbContext _accounting;
        private readonly ILedgerService _ledger;
        private readonly UserManager<AppUser> _users;
        private readonly IAdminAuditService _audit;

        public DriverCashAdvancesController(AccountingDbContext accounting, ILedgerService ledger,
            UserManager<AppUser> users, IAdminAuditService audit)
        {
            _accounting = accounting;
            _ledger = ledger;
            _users = users;
            _audit = audit;
        }

        [HttpGet("overview")]
        public async Task<ActionResult<object>> Overview()
        {
            var drivers = (await _users.GetUsersInRoleAsync(AppRoleName.Delivery.ToString()))
                .Where(x => x.IsActive && x.DeletionDate == null)
                .OrderBy(x => x.FullName)
                .ToArray();

            var driverItems = new List<object>(drivers.Length);
            foreach (var driver in drivers)
            {
                var balance = await _ledger.GetUserCashFloatBalanceAsync(driver.Id, Currency);
                driverItems.Add(new
                {
                    id = driver.Id,
                    name = driver.FullName ?? string.Join(" ", new[] { driver.FirstName, driver.LastName }.Where(x => !string.IsNullOrWhiteSpace(x))),
                    balance,
                    maxCashFloat = driver.MaxCashFloat,
                    remainingCapacity = Math.Max(0m, driver.MaxCashFloat - balance)
                });
            }

            var vault = await _accounting.Accounts.AsNoTracking().FirstOrDefaultAsync(a =>
                a.AccountCode == SystemAccountCodes.CompanyMainVault && a.Currency == Currency &&
                a.Type == AccountType.Asset && a.IsActive);
            var vaultBalance = vault == null ? 0m : await _ledger.GetAccountBalanceAsync(vault.Id);

            var recentTransactions = await _accounting.JournalTransactions.AsNoTracking()
                .Where(t => t.ReferenceType == ReferenceType)
                .Include(t => t.Entries).ThenInclude(e => e.Account)
                .OrderByDescending(t => t.PostedDate).Take(20).ToListAsync();
            var recentDriverIds = recentTransactions.SelectMany(t => t.Entries)
                .Where(e => e.Account.AccountCode.StartsWith(SystemAccountCodes.CaptainCashFloatPrefix))
                .Select(e => e.Account.OwnerUserId).Where(id => id.HasValue).Select(id => id.Value)
                .Distinct().ToArray();
            var recentDriverNames = await _users.Users.AsNoTracking()
                .Where(u => recentDriverIds.Contains(u.Id))
                .Select(u => new { u.Id, u.FullName, u.FirstName, u.LastName })
                .ToDictionaryAsync(u => u.Id, u => u.FullName ?? (u.FirstName + " " + u.LastName));
            var advances = recentTransactions.Select(t =>
            {
                var entry = t.Entries.FirstOrDefault(e =>
                    e.Account.AccountCode.StartsWith(SystemAccountCodes.CaptainCashFloatPrefix) && e.Debit > 0);
                var driverId = entry?.Account.OwnerUserId;
                return new
                {
                    transactionNumber = t.TransactionNumber,
                    postedAt = t.PostedDate,
                    driverUserId = driverId,
                    driverName = driverId.HasValue && recentDriverNames.TryGetValue(driverId.Value, out var name) ? name : "مندوب محذوف",
                    amount = entry?.Debit ?? 0m,
                    reference = t.ReferenceId,
                    description = t.Description
                };
            }).ToArray();

            return Ok(new { currency = Currency, companyVaultBalance = vaultBalance, drivers = driverItems, recentAdvances = advances });
        }

        [HttpPost]
        public async Task<ActionResult<object>> Create([FromBody] CreateDriverCashAdvanceRequest request)
        {
            if (request == null || request.DriverUserId == Guid.Empty || request.Amount <= 0m ||
                request.Amount > 1_000_000_000m || string.IsNullOrWhiteSpace(request.IdempotencyKey) ||
                request.IdempotencyKey.Length > 100 || string.IsNullOrWhiteSpace(request.Reason) ||
                request.Reason.Trim().Length > 300)
                return BadRequest(ApiErr.Create("أدخل المندوب والمبلغ وسبب صرف العهدة بشكل صحيح."));

            var driver = await _users.FindByIdAsync(request.DriverUserId.ToString());
            if (driver == null || !driver.IsActive || driver.DeletionDate != null ||
                !await _users.IsInRoleAsync(driver, AppRoleName.Delivery.ToString()))
                return BadRequest(ApiErr.Create("المستخدم المحدد ليس مندوب توصيل نشطاً."));
            if (driver.MaxCashFloat <= 0m)
                return BadRequest(ApiErr.Create("سقف العهدة لهذا المندوب غير مضبوط."));

            var idempotencyKey = $"DriverCashAdvance-{request.IdempotencyKey.Trim()}";
            var existing = await _accounting.JournalTransactions.AsNoTracking()
                .Where(t => t.IdempotencyKey == idempotencyKey)
                .Include(t => t.Entries).ThenInclude(e => e.Account)
                .FirstOrDefaultAsync();
            if (existing != null)
                return ExistingAdvanceMatches(existing, driver.Id, request.Amount)
                    ? Ok(new { transactionNumber = existing.TransactionNumber, amount = request.Amount,
                        balance = await _ledger.GetUserCashFloatBalanceAsync(driver.Id, Currency), replayed = true })
                    : Conflict(ApiErr.Create("مفتاح العملية مستخدم مسبقاً لعملية عهدة مختلفة."));

            IDbContextTransaction dbTransaction = null;
            if (_accounting.Database.IsRelational())
                dbTransaction = await _accounting.Database.BeginTransactionAsync(IsolationLevel.Serializable);

            try
            {
                var floatAccount = await _ledger.GetOrCreateUserAccountAsync(driver.Id, AccountType.Asset,
                    SystemAccountCodes.CaptainCashFloatPrefix, $"Cash Float - {driver.FullName ?? driver.UserName}", Currency);
                var vaultAccount = await _ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.CompanyMainVault,
                    "Company Cash Vault", AccountType.Asset, Currency);
                var currentBalance = await _ledger.GetAccountBalanceAsync(floatAccount.Id);
                var vaultBalance = await _ledger.GetAccountBalanceAsync(vaultAccount.Id);

                if (currentBalance + request.Amount > driver.MaxCashFloat)
                    return BadRequest(ApiErr.Create($"المبلغ يتجاوز المساحة المتاحة ضمن سقف العهدة. الرصيد الحالي {currentBalance:N2}، والسقف {driver.MaxCashFloat:N2} ل.س."));
                if (vaultBalance < request.Amount)
                    return BadRequest(ApiErr.Create($"رصيد خزينة الشركة غير كافٍ لصرف العهدة. الرصيد المتاح {vaultBalance:N2} ل.س."));

                var before = new { driverId = driver.Id, balance = currentBalance, maxCashFloat = driver.MaxCashFloat, vaultBalance };
                var posted = await _ledger.PostTransactionAsync(new PostTransactionRequest
                {
                    ReferenceType = ReferenceType,
                    ReferenceId = request.IdempotencyKey.Trim(),
                    IdempotencyKey = idempotencyKey,
                    Description = $"Driver cash advance for {driver.FullName ?? driver.UserName}: {request.Reason.Trim()}",
                    Entries = new List<PostLedgerEntryRequest>
                    {
                        new() { AccountId = floatAccount.Id, Debit = request.Amount, Currency = Currency,
                            Memo = $"عهدة تشغيلية للمندوب. السبب: {request.Reason.Trim()}" },
                        new() { AccountId = vaultAccount.Id, Credit = request.Amount, Currency = Currency,
                            Memo = "صرف نقدي من خزينة الشركة إلى عهدة المندوب" }
                    }
                });

                var committed = await _accounting.JournalTransactions.AsNoTracking()
                    .Where(t => t.IdempotencyKey == idempotencyKey)
                    .Include(t => t.Entries).ThenInclude(e => e.Account)
                    .FirstOrDefaultAsync();
                if (committed == null || !ExistingAdvanceMatches(committed, driver.Id, request.Amount))
                {
                    if (dbTransaction != null) await dbTransaction.RollbackAsync();
                    return Conflict(ApiErr.Create("مفتاح العملية مستخدم لعملية أخرى؛ لم تُسجل هذه العهدة."));
                }

                var afterBalance = await _ledger.GetAccountBalanceAsync(floatAccount.Id);
                var afterVaultBalance = await _ledger.GetAccountBalanceAsync(vaultAccount.Id);
                if (afterBalance > driver.MaxCashFloat)
                    throw new InvalidOperationException("Posting this advance would exceed the driver's cash custody limit.");
                if (dbTransaction != null) await dbTransaction.CommitAsync();

                try
                {
                    var actorId = User.GetUserId();
                    var actor = actorId.HasValue ? await _users.FindByIdAsync(actorId.Value.ToString()) : null;
                    await _audit.LogAsync(new AdminAuditLogEntry
                    {
                        AdminUserId = actorId,
                        AdminName = actor?.FullName,
                        AdminEmail = actor?.Email,
                        Module = "Finance",
                        Action = "DriverCashAdvance",
                        EntityType = "JournalTransaction",
                        EntityId = posted.Id.ToString(),
                        Description = $"تم صرف عهدة تشغيلية للمندوب {driver.FullName ?? driver.UserName} بقيمة {request.Amount:N2} ل.س. السبب: {request.Reason.Trim()}",
                        BeforeState = before,
                        AfterState = new { driverId = driver.Id, balance = afterBalance, maxCashFloat = driver.MaxCashFloat, vaultBalance = afterVaultBalance, transactionNumber = posted.TransactionNumber }
                    });
                }
                catch { /* The balanced journal remains the authoritative audit trail. */ }

                return Ok(new { transactionNumber = posted.TransactionNumber, amount = request.Amount,
                    balance = afterBalance, remainingCapacity = Math.Max(0m, driver.MaxCashFloat - afterBalance), replayed = false });
            }
            catch (InvalidOperationException ex)
            {
                if (dbTransaction != null) await dbTransaction.RollbackAsync();
                return BadRequest(ApiErr.Create(ex.Message));
            }
            finally
            {
                if (dbTransaction != null) await dbTransaction.DisposeAsync();
            }
        }

        private static bool ExistingAdvanceMatches(JournalTransaction transaction, Guid driverId, decimal amount)
        {
            var driverEntry = transaction.Entries.FirstOrDefault(e =>
                e.Account.OwnerUserId == driverId && e.Account.AccountCode.StartsWith(SystemAccountCodes.CaptainCashFloatPrefix));
            var vaultEntry = transaction.Entries.FirstOrDefault(e => e.Account.AccountCode == SystemAccountCodes.CompanyMainVault);
            return driverEntry != null && vaultEntry != null && driverEntry.Debit == amount && driverEntry.Credit == 0m &&
                vaultEntry.Credit == amount && vaultEntry.Debit == 0m;
        }
    }

    public class CreateDriverCashAdvanceRequest
    {
        public Guid DriverUserId { get; set; }
        public decimal Amount { get; set; }
        public string Reason { get; set; }
        public string IdempotencyKey { get; set; }
    }
}
