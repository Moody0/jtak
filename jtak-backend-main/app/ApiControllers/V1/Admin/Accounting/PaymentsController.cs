using App.ApiModels;
using App.Shared.Services;
using AutoMapper;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Threading.Tasks;
using System;
using System.Collections.Generic;
using System.Data;
using OpenIddict.Validation.AspNetCore;
using Microsoft.AspNetCore.Authorization;
using System.Linq;
using App.Shared.Data.App;
using App.Shared.Entities.Enums;
using App.Shared.Entities;
using Solf.Models;
using Modules.Catalog.Services;
using App.Extensions;
using Modules.Shipping.Services;
using Modules.Accounting.Services;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;

namespace App.ApiControllers.V1.Admin
{
    [Route("api/v{version:apiVersion}/Admin/[controller]")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.AdminPermission))]
    public class PaymentsController : SolApiController
    {
        private readonly IAppUnitOfWork _uow;
        private readonly IAccountingUnitOfWork _auow;
        private readonly INotificationService _notificationService;
        private readonly UserManager<AppUser> _userManager;
        private readonly IMapper _mapper;
        private readonly IMerchantService _merchantService;
        private readonly IDeliveryService _deliveryService;
        private readonly IPaymentService _service;
        private readonly IBillService _billService;
        private readonly IBalanceService _balanceService;
        private readonly ILedgerService _ledgerService;
        private readonly ISettlementHistoryService _settlementHistoryService;
        private readonly IAdminAuditService _auditService;
        private readonly App.Orders.Data.OrdersDbContext _ordersDb;

        public PaymentsController(IAppUnitOfWork unitOfWork,
            IAccountingUnitOfWork auow,
            INotificationService notificationService,
            UserManager<AppUser> userManager,
            IMerchantService merchantService,
            IDeliveryService deliveryService,
            IPaymentService service,
            IBillService billService,
            IBalanceService balanceService,
            ILedgerService ledgerService,
            ISettlementHistoryService settlementHistoryService,
            IMapper mapper,
            IAdminAuditService auditService = null,
            App.Orders.Data.OrdersDbContext ordersDb = null)
        {
            _uow = unitOfWork;
            _auow = auow;
            _userManager = userManager;
            _notificationService = notificationService;
            _mapper = mapper;
            _merchantService = merchantService;
            _deliveryService = deliveryService;
            _service = service;
            _billService = billService;
            _balanceService = balanceService;
            _ledgerService = ledgerService;
            _settlementHistoryService = settlementHistoryService;
            _auditService = auditService;
            _ordersDb = ordersDb;
        }


        /// <summary>
        /// Get a paged/filtered/Paymented list of Payments
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Route("DataTable")]
        public async Task<ActionResult<TableResponseModel<PaymentDto>>> DataTable([FromBody] MetronicTable request)
        {
            request ??= new MetronicTable();
            var history = await _settlementHistoryService.GetCompletedItemsAsync();
            var items = history.Select((item, index) => new PaymentDto
            {
                // The settlement request number is the authoritative reference;
                // the legacy integer payment id is not applicable here.
                Id = index + 1,
                ReferenceNumber = item.RequestNumber,
                PaymentType = item.PartyTypeLabel,
                Currency = item.Currency,
                Status = item.Status,
                IsSettlement = true,
                ToUser = item.PartyName,
                ToUserId = item.DriverId ?? Guid.Empty,
                MerchantId = item.MerchantId ?? 0,
                ByUser = item.ConfirmedBy ?? item.ApprovedBy,
                Amount = item.Amount,
                CreatedDate = item.RequestedAt,
                HandoverDate = item.CompletedAt,
                NewBalance = 0m
            }).ToList();
            var payments = await _service.Queryable().AsNoTracking().Where(p=>!_auow.Context.DailySettlementBatches.Any(b=>p.HandoverDate==b.BatchDate && p.ByUserId==b.CaptainUserId && p.ToUserId==b.HandledByAdminId)).ToListAsync();
            var references = payments.Select(p => $"Payment-{p.Id}").ToArray();
            var postedReferences = await _auow.Context.JournalTransactions.AsNoTracking().Where(t => t.ReferenceType == "CaptainToMerchantPayment" && references.Contains(t.ReferenceId))
                .Select(t=>t.ReferenceId).ToListAsync();
            items.AddRange(payments.Select(p => new PaymentDto { ReferenceNumber=$"Payment-{p.Id}", Amount=p.Amount, ToUser=p.ToUser, ToUserId=p.ToUserId,
                ByUser=p.ByUser,ByUserId=p.ByUserId,CreatedDate=p.CreatedDate,HandoverDate=p.HandoverDate ?? (postedReferences.Contains($"Payment-{p.Id}") ? p.CreatedDate : (DateTime?)null),
                Status=p.HandoverDate.HasValue || postedReferences.Contains($"Payment-{p.Id}") ? "Completed" : "Pending", PaymentType="دفعة للمتجر من عهدة المندوب",Currency="SYP",NewBalance=p.NewBalance }));
            if (!string.IsNullOrWhiteSpace(request.Search)) {
                var term=request.Search.Trim();
                items=items.Where(p=>new[]{p.ReferenceNumber,p.ToUser,p.ByUser,p.PaymentType,p.Amount.ToString(System.Globalization.CultureInfo.InvariantCulture)}.Any(s=>s?.Contains(term,StringComparison.OrdinalIgnoreCase)==true)).ToList();
            }
            var completed=items.Where(p=>p.Status=="Completed" && p.Currency=="SYP").ToList();
            var total=completed.Sum(p=>p.Amount);
            var summary=new {RecordsCount=items.Count,TotalPaid=total,AveragePayment=completed.Count>0 ? decimal.Round(total/completed.Count,2) : 0m,
                UniqueRecipients=items.Where(p=>p.Status=="Completed").Select(p=>p.MerchantId>0 ? $"Merchant-{p.MerchantId}" : p.ToUserId!=Guid.Empty ? $"User-{p.ToUserId}" : p.ToUser).Distinct().Count(),
                CurrencyTotals=items.Where(p=>p.Status=="Completed").GroupBy(p=>p.Currency).Select(g=>new {Currency=g.Key,TotalPaid=g.Sum(p=>p.Amount)}).ToArray()};
            var ascending=string.Equals(request.SortOrder,"ASC",StringComparison.OrdinalIgnoreCase);
            Func<PaymentDto,IComparable> sort=(request.SortField ?? "createdDate").ToLowerInvariant() switch {
                "amount"=>p=>p.Amount,"touser"=>p=>p.ToUser ?? "","byuser"=>p=>p.ByUser ?? "","handoverdate"=>p=>p.HandoverDate ?? DateTime.MinValue,
                "referencenumber"=>p=>p.ReferenceNumber ?? "",_=>p=>p.CreatedDate ?? DateTime.MinValue
            };
            var ordered=ascending ? items.OrderBy(sort).ThenBy(p=>p.ReferenceNumber) : items.OrderByDescending(sort).ThenBy(p=>p.ReferenceNumber);
            var page=ordered.Skip((Math.Max(1,request.PageNumber)-1)*Math.Clamp(request.PageSize,1,1000)).Take(Math.Clamp(request.PageSize,1,1000)).ToArray();
            for(var i=0;i<page.Length;i++)page[i].Id=(Math.Max(1,request.PageNumber)-1)*Math.Clamp(request.PageSize,1,1000)+i+1;
            return Ok(new { Items=page,TotalRecords=items.Count,TotalRecordsFiltered=items.Count,Summary=summary });
        }

        [HttpPost]
        [Route("Create")]
        public async Task<ActionResult<bool>> Create(PaymentDto dto)
        {
            if (dto == null || dto.ByUserId == Guid.Empty || dto.ToUserId == Guid.Empty || dto.ByUserId == dto.ToUserId || dto.Amount <= 0m ||
                dto.Amount > 1_000_000_000m || dto.Amount != decimal.Round(dto.Amount, 2) || string.IsNullOrWhiteSpace(dto.RequestKey) || dto.RequestKey.Length > 100)
                return BadRequest(ApiErr.Create("بيانات الدفعة غير صالحة."));
            var safety = new DriverFinancialSafetyService(_auow.Context, _ledgerService, _uow?.Context as AppDbContext, _ordersDb);
            return await safety.WithDriverLockAsync(dto.ByUserId, () => CreateCoreAsync(dto, safety));
        }

        private async Task<ActionResult<bool>> CreateCoreAsync(PaymentDto dto, DriverFinancialSafetyService safety)
        {
            await using var transaction = _auow.Context.Database.IsRelational()
                ? await _auow.Context.Database.BeginTransactionAsync(IsolationLevel.Serializable)
                : null;
            try
            {
                var merchant = dto.MerchantId > 0
                    ? await _merchantService.Queryable().AsNoTracking().FirstOrDefaultAsync(m => m.Id == dto.MerchantId && m.OwnerId == dto.ToUserId)
                    : null;
                if (merchant == null && dto.MerchantId <= 0)
                {
                    var candidates = await _merchantService.Queryable().AsNoTracking().Where(m => m.OwnerId == dto.ToUserId).Take(2).ToListAsync();
                    if (candidates.Count == 1) merchant = candidates[0];
                }
                if (merchant == null) return BadRequest(ApiErr.Create("حدد المتجر المستلم نفسه، وليس حساب مالك عدة متاجر."));

                var driver = await _userManager.FindByIdAsync(dto.ByUserId.ToString());
                var recipient = await _userManager.FindByIdAsync(dto.ToUserId.ToString());
                if (driver == null || !driver.IsActive || driver.DeletionDate != null || !await _userManager.IsInRoleAsync(driver, AppRoleName.Delivery.ToString()) || recipient == null)
                    return BadRequest(ApiErr.Create("اختر مندوب توصيل نشطاً ومتجراً له حساب مالك صحيح."));

                // Double-submit protection: an identical payment still awaiting confirmation that was
                // created moments ago is the same operation, not a new one.
                var since = DateTime.UtcNow.AddMinutes(-2);
                var duplicate = (await safety.GetUnconfirmedMerchantPaymentsAsync(dto.ByUserId, dto.ToUserId))
                    .Any(p => p.ToUser == merchant.Title && p.Amount == dto.Amount && p.CreatedDate >= since);
                if (duplicate) return Ok(true);

                var position = await safety.GetPositionAsync(dto.ByUserId);
                var available = await MerchantAvailableAsync(merchant.Id);
                if (dto.Amount > position.SpendableCash)
                    return BadRequest(ApiErr.Create($"المبلغ يتجاوز العهدة المتاحة بعد المبالغ المحجوزة ({position.SpendableCash:N2} ل.س)."));
                if (dto.Amount > available)
                    return BadRequest(ApiErr.Create($"المبلغ يتجاوز مستحقات المتجر المتاحة بعد التسويات المحجوزة ({available:N2} ل.س)."));

                // The payment is only recorded here (HandoverDate == null => "قيد التسليم").
                // The courier cash float, merchant payable and app balances are NOT touched until the
                // merchant confirms receipt (Warehouse/Payments/RecivePayment). Meanwhile the amount is
                // reserved on both sides so it cannot be spent or paid out twice.
                var payment = new Payment { ByUserId = dto.ByUserId, ByUser = driver.FullName, ToUserId = dto.ToUserId, ToUser = merchant.Title,
                    // Record the actual balance at creation, not a hypothetical
                    // balance after deduction. Receipt confirmation updates it later.
                    Amount = dto.Amount, NewBalance = await _ledgerService.GetMerchantPayableBalanceAsync(merchant.Id), HandoverDate = null };
                _service.Insert(payment);
                await _auow.SaveChangesAsync();
                if (transaction != null) await transaction.CommitAsync();
                try {
                    if (_auditService != null) await _auditService.LogAsync(new AdminAuditLogEntry
                    {
                        Module = "Settlements", Action = "Pay", EntityType = "Payment", EntityId = payment.Id.ToString(),
                        Description = $"إنشاء دفعة {dto.Amount:N2} ل.س للمتجر {merchant.Title} عبر المندوب {driver.FullName} بانتظار تأكيد التاجر", Result = "Success",
                        AfterState = new { payment.Id, payment.Amount, payment.ByUserId, payment.ToUserId, MerchantId = merchant.Id, Status = "PendingMerchantConfirmation" }
                    });
                } catch { /* The payment record itself is the source of truth. */ }
                return Ok(true);
            }
            catch (InvalidOperationException ex) { if (transaction != null) await transaction.RollbackAsync(); return BadRequest(ApiErr.Create(ex.Message)); }
            catch
            {
                if (transaction != null) await transaction.RollbackAsync();
                throw;
            }
        }

        private async Task<decimal> MerchantAvailableAsync(int merchantId)
        {
            if (_ordersDb != null && await _ordersDb.Orders.AnyAsync(o => o.AccountingStatus == Modules.Orders.Entities.OrderAccountingStatus.PendingAccounting && o.OrderDetails.Any(d => d.MerchantId == merchantId))) return 0m;
            var reserved = await _auow.Context.SettlementRequestMerchantAllocations.Where(a => a.MerchantId == merchantId && a.SettlementRequest.Currency == "SYP" &&
                (a.SettlementRequest.Status == SettlementRequestStatus.Pending || a.SettlementRequest.Status == SettlementRequestStatus.Approved)).SumAsync(a => (decimal?)a.Amount) ?? 0m;
            // Courier payments awaiting the merchant's confirmation are not deducted yet, but are reserved.
            var merchant = await _merchantService.Queryable().AsNoTracking().Where(m => m.Id == merchantId).Select(m => new { m.OwnerId, m.Title }).FirstOrDefaultAsync();
            if (merchant != null)
            {
                var ownerStores = await _merchantService.Queryable().AsNoTracking().CountAsync(m => m.OwnerId == merchant.OwnerId);
                var safety = new DriverFinancialSafetyService(_auow.Context, _ledgerService, _uow?.Context as AppDbContext, _ordersDb);
                reserved += (await safety.GetUnconfirmedMerchantPaymentsAsync(merchantOwnerId: merchant.OwnerId))
                    .Where(p => ownerStores <= 1 || p.ToUser == merchant.Title).Sum(p => p.Amount);
            }
            return Math.Max(0m, await _ledgerService.GetMerchantPayableBalanceAsync(merchantId) - reserved);
        }

        [HttpGet("AvailableBalances")]
        public async Task<ActionResult<object>> AvailableBalances([FromQuery] Guid? driverId, [FromQuery] int? merchantId) => Ok(new {
            deliveryBalance = driverId.HasValue ? (await new DriverFinancialSafetyService(_auow.Context, _ledgerService, _uow?.Context as AppDbContext, _ordersDb).GetPositionAsync(driverId.Value)).SpendableCash : (decimal?)null,
            merchantBalance = merchantId.HasValue ? await MerchantAvailableAsync(merchantId.Value) : (decimal?)null
        });

        [HttpPost]
        [Route("{id}/ReconcileToMerchant")]
        public async Task<ActionResult<bool>> ReconcileToMerchant(int id)
        {
            var driverId = await _auow.Context.Payments.Where(p => p.Id == id).Select(p => (Guid?)p.ByUserId).FirstOrDefaultAsync();
            if (!driverId.HasValue) return NotFound(ApiErr.Create("الدفعة غير موجودة."));
            return await new DriverFinancialSafetyService(_auow.Context, _ledgerService, _uow?.Context as AppDbContext, _ordersDb)
                .WithDriverLockAsync(driverId.Value, () => ReconcileToMerchantCore(id));
        }

        private async Task<ActionResult<bool>> ReconcileToMerchantCore(int id)
        {
            await using var transaction = _auow.Context.Database.IsRelational() ? await _auow.Context.Database.BeginTransactionAsync(IsolationLevel.Serializable) : null;
            var payment = await _auow.Context.Set<Payment>().FirstOrDefaultAsync(x => x.Id == id);
            if (payment == null) return NotFound(ApiErr.Create("الدفعة غير موجودة."));

            var reference = $"Payment-{payment.Id}";
            if (await _auow.Context.JournalTransactions.AnyAsync(t=>t.ReferenceType=="CaptainToMerchantPayment" && t.ReferenceId==reference)) return Ok(true);

            var mids = await _merchantService.GetMerchantIds(payment.ToUserId);
            var merchantId = mids?.Length == 1 ? mids[0] : 0;
            if (merchantId <= 0)
                return BadRequest(ApiErr.Create("المستلم ليس متجراً صالحاً للتسوية."));

            var merchantName = await _userManager.Users.Where(x => x.Id == payment.ToUserId).Select(x => x.FullName).FirstOrDefaultAsync() ?? payment.ToUser;

            var idempotencyKey = $"Fix-Payment-{payment.Id}-ReallocateToMerchant";
            var original = await _auow.Context.JournalTransactions.Include(t=>t.Entries).ThenInclude(e=>e.Account).FirstOrDefaultAsync(t=>t.ReferenceType=="CaptainCashHandover" && t.ReferenceId==reference);
            if(original==null || !original.Entries.Any(e=>e.Account.AccountCode==SystemAccountCodes.CompanyMainVault && e.Debit==payment.Amount))
                return BadRequest(ApiErr.Create("لا يوجد ترحيل قديم للخزينة يحتاج تصحيحاً لهذه الدفعة."));
            var existingTxn = await _auow.Context.Set<JournalTransaction>().FirstOrDefaultAsync(x => x.IdempotencyKey == idempotencyKey);
            if (existingTxn == null)
            {
                var vendorPayable = await _ledgerService.GetOrCreateMerchantAccountAsync(merchantId, "SYP");
                var vault = await _ledgerService.GetOrCreateSystemAccountAsync(SystemAccountCodes.CompanyMainVault, "Company Cash Vault", AccountType.Asset, "SYP");

                await _ledgerService.PostTransactionAsync(new PostTransactionRequest
                {
                    ReferenceType = "PaymentAdjustment",
                    ReferenceId = payment.Id.ToString(),
                    IdempotencyKey = idempotencyKey,
                    Description = $"تصحيح ترحيل الدفعة #{payment.Id}: تحويل خصم {payment.Amount:N0} ل.س من خزينة الشركة إلى ذمم متجر {merchantName}",
                    Entries = new List<PostLedgerEntryRequest>
                    {
                        new() { AccountId = vendorPayable.Id, Debit = payment.Amount, Currency = "SYP", Memo = $"تسديد نقدي للمتجر من عهدة الكابتن - تصحيح دفعة #{payment.Id}" },
                        new() { AccountId = vault.Id, Credit = payment.Amount, Currency = "SYP", Memo = $"تعديل ترحيل الخزينة للدفعة #{payment.Id} إلى المتجر" }
                    }
                });

                var merchantBalance = await _ledgerService.GetMerchantPayableBalanceAsync(merchantId, "SYP");
                var mirror = await _auow.Context.Balances.SingleOrDefaultAsync(b => b.Id == payment.ToUserId);
                if (mirror != null) mirror.Amount = merchantBalance;
                payment.NewBalance = await _ledgerService.GetUserCashFloatBalanceAsync(payment.ByUserId, "SYP");
                await _auow.SaveChangesAsync();
            }
            if (transaction != null) await transaction.CommitAsync();
            return Ok(true);
        }
    }
}
