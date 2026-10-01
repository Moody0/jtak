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
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.DeliveryPermission))]
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
            IAdminAuditService auditService = null)
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
            var history = await _settlementHistoryService.GetDataTableAsync(new SettlementHistoryDataTableRequest
            {
                SearchTerm = request.Search,
                PartyFilter = SettlementHistoryPartyFilter.All,
                Page = request.PageNumber > 0 ? request.PageNumber : 1,
                PageSize = request.PageSize > 0 ? request.PageSize : 10,
                SortColumn = string.IsNullOrWhiteSpace(request.SortField) ? "CompletedAt" : request.SortField,
                SortDirection = string.IsNullOrWhiteSpace(request.SortOrder) ? "DESC" : request.SortOrder
            });

            var items = history.Items.Select((item, index) => new PaymentDto
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
                ByUser = item.ConfirmedBy ?? item.ApprovedBy,
                Amount = item.Amount,
                CreatedDate = item.RequestedAt,
                HandoverDate = item.CompletedAt,
                NewBalance = 0m
            }).ToList();

            return Ok(new TableResponseModel<PaymentDto>
            {
                Items = items.ToArray(),
                TotalRecords = history.TotalRecords
            });
        }

        [HttpPost]
        [Route("Create")]
        public async Task<ActionResult<bool>> Create(PaymentDto dto)
        {
            if (dto == null || dto.ByUserId == Guid.Empty || dto.ToUserId == Guid.Empty || dto.Amount <= 0m)
                return BadRequest(ApiErr.Create("بيانات الدفعة غير صالحة."));

            // Create new payment
            var byUser = await _userManager.Users.Where(x => x.Id == dto.ByUserId).Select(x => x.FullName).FirstOrDefaultAsync();
            var toUser = await _userManager.Users.Where(x => x.Id == dto.ToUserId).Select(x => x.FullName).FirstOrDefaultAsync();
            var dBalance = await _balanceService.GetBalance(dto.ByUserId);
            var ledgerBalance = await _ledgerService.GetUserCashFloatBalanceAsync(dto.ByUserId);
            if (ledgerBalance + 0.001m < dto.Amount)
                return BadRequest(ApiErr.Create($"المبلغ المطلوب يتجاوز عهدة المندوب المتاحة ({ledgerBalance:N0})."));

            var newBalance = Math.Max(0m, dBalance.Amount - dto.Amount);
            var payment = new Payment
            {
                ByUserId = dto.ByUserId,
                ByUser = byUser,
                ToUserId = dto.ToUserId,
                ToUser = toUser,
                NewBalance = newBalance,
                Amount = dto.Amount
            };
            await using var transaction = _auow.Context.Database.IsRelational()
                ? await _auow.Context.Database.BeginTransactionAsync(IsolationLevel.Serializable)
                : null;
            try
            {
                _service.Insert(payment);
                await _auow.SaveChangesAsync();

                var mids = await _merchantService.GetMerchantIds(dto.ToUserId);
                var merchantId = mids != null && mids.Length > 0 ? mids[0] : 0;

                if (merchantId > 0)
                {
                    await _ledgerService.PostCaptainToMerchantPaymentAsync(
                        dto.ByUserId,
                        merchantId,
                        dto.Amount,
                        $"Payment-{payment.Id}",
                        byUser,
                        toUser);
                }
                else
                {
                    await _ledgerService.PostCaptainCashHandoverAsync(
                        dto.ByUserId,
                        dto.Amount,
                        $"Payment-{payment.Id}",
                        byUser);
                }

                // Keep the legacy balance as a compatibility mirror while the
                // ledger remains the source of truth for current app screens.
                await _balanceService.UpdateAppBalance(new BalanceDto { Amount = newBalance, PendingAmount = dBalance.PendingAmount, Id = dto.ByUserId, Name = byUser });
                if (merchantId > 0)
                {
                    await _balanceService.DecreaseAppBalance(dto.ToUserId, dto.Amount, toUser);
                }
                await _auow.SaveChangesAsync();
                if (transaction != null) await transaction.CommitAsync();

                if (_auditService != null)
                {
                    await _auditService.LogAsync(new AdminAuditLogEntry
                    {
                        Module = "Settlements",
                        Action = "Pay",
                        EntityType = "Payment",
                        EntityId = payment.Id.ToString(),
                        Description = $"تحويل دفعة مالية بقيمة {dto.Amount:N0} ل.س من {byUser} إلى {toUser}",
                        Result = "Success",
                        AfterState = new { payment.Id, payment.Amount, payment.ByUserId, ByUser = byUser, payment.ToUserId, ToUser = toUser, payment.NewBalance }
                    });
                }
            }
            catch
            {
                if (transaction != null) await transaction.RollbackAsync();
                throw;
            }
            return true;
        }

        [HttpPost]
        [Route("{id}/ReconcileToMerchant")]
        public async Task<ActionResult<bool>> ReconcileToMerchant(int id)
        {
            var payment = await _auow.Context.Set<Payment>().FirstOrDefaultAsync(x => x.Id == id);
            if (payment == null) return NotFound(ApiErr.Create("الدفعة غير موجودة."));

            var mids = await _merchantService.GetMerchantIds(payment.ToUserId);
            var merchantId = mids != null && mids.Length > 0 ? mids[0] : 0;
            if (merchantId <= 0)
                return BadRequest(ApiErr.Create("المستلم ليس متجراً صالحاً للتسوية."));

            var merchantName = await _userManager.Users.Where(x => x.Id == payment.ToUserId).Select(x => x.FullName).FirstOrDefaultAsync() ?? payment.ToUser;

            var idempotencyKey = $"Fix-Payment-{payment.Id}-ReallocateToMerchant";
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

                var mBalance = await _balanceService.GetBalance(payment.ToUserId);
                if (mBalance != null && mBalance.Amount > 0)
                {
                    await _balanceService.DecreaseAppBalance(payment.ToUserId, payment.Amount, merchantName);
                }

                payment.NewBalance = Math.Max(0m, (mBalance?.Amount ?? payment.Amount) - payment.Amount);
                await _auow.SaveChangesAsync();
            }

            return Ok(true);
        }
    }
}
