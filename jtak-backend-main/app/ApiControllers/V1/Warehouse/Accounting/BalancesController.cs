using App.ApiModels;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System;
using System.Linq;
using System.Threading.Tasks;
using OpenIddict.Validation.AspNetCore;
using Microsoft.AspNetCore.Authorization;
using App.Shared.Entities.Enums;
using App.Extensions;
using Modules.Accounting.Services;
using Modules.Accounting.Entities;
using Modules.Catalog.Services;

using App.Shared.Entities;
using App.Shared.Entities.Domain;
using App.Shared.Services;
using App.Shared.Data.App;
using Microsoft.AspNetCore.Identity;
using System.ComponentModel.DataAnnotations;
using App.Shared.Services.Extentions;
using System.Collections.Generic;

namespace App.ApiControllers.V1.Warehouse
{
    [Route("api/v{version:apiVersion}/Warehouse/[controller]")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.MerchantPermission))]
    public class BalancesController : SolApiController
    {
        private readonly IBalanceService _service;
        private readonly IMerchantService _merchantService;
        private readonly IBillService _billService;
        private readonly IPaymentService _paymentService;
        private readonly UserManager<AppUser> _userManager;
        private readonly ISupportMessageService _supportService;
        private readonly IAppUnitOfWork _uow;
        private readonly ISettlementRequestService _settlements;
        private readonly INotificationService _notifications;

        public BalancesController(
            IBalanceService service,
            IMerchantService merchantService,
            IBillService billService,
            IPaymentService paymentService,
            UserManager<AppUser> userManager = null,
            ISupportMessageService supportService = null,
            IAppUnitOfWork uow = null,
            ISettlementRequestService settlements = null,
            INotificationService notifications = null)
        {
            _service = service;
            _merchantService = merchantService;
            _billService = billService;
            _paymentService = paymentService;
            _userManager = userManager;
            _supportService = supportService;
            _uow = uow;
            _settlements = settlements;
            _notifications = notifications;
        }

        /// <summary>
        /// Get my Balance
        /// </summary>
        [HttpPost]
        [Route("Mine")]
        public async Task<ActionResult<object>> GetMine()
        {
            var uid = User.GetUserId();
            if (!uid.HasValue) return Unauthorized();
            var mids = await _merchantService.GetMerchantIds(uid.Value);
            var position = await _settlements.GetMerchantBalanceAsync(mids);
            return Ok(new { id = uid.Value, amount = position.AvailableAmount, pendingAmount = position.PendingAmount, grossAmount = position.GrossAmount, currency = position.Currency });
        }

        /// <summary>
        /// Request a payout/settlement from available balance
        /// </summary>
        [HttpPost]
        [Route("RequestSettlement")]
        public async Task<ActionResult> RequestSettlement([FromBody] SettlementRequestDto model)
        {
            var uid = User.GetUserId();
            if (!uid.HasValue) return Unauthorized();

            if (model == null)
            {
                return BadRequest(ApiErr.Create("بيانات الطلب غير صالحة"));
            }

            if (model.Amount <= 0)
            {
                return BadRequest(ApiErr.Create("يرجى إدخال مبلغ صحيح أكبر من الصفر"));
            }

            if (string.IsNullOrWhiteSpace(model.AccountDetails))
            {
                return BadRequest(ApiErr.Create("يرجى إدخال بيانات التحويل (رقم الحساب / رقم الهاتف)"));
            }

            var mids = await _merchantService.GetMerchantIds(uid.Value);
            var ownedMerchants = await _merchantService.Queryable()
                .Where(x => mids.Contains(x.Id))
                .Select(x => new MerchantSettlementSource { MerchantId = x.Id, MerchantTitle = x.Title })
                .ToListAsync();
            var position = await _settlements.GetMerchantBalanceAsync(mids);
            var currentBalance = position.AvailableAmount;

            if (currentBalance <= 0)
            {
                return BadRequest(ApiErr.Create("لا يوجد رصيد متاح للسحب حالياً"));
            }

            if (model.Amount > currentBalance)
            {
                return BadRequest(ApiErr.Create($"المبلغ المطلوب ({model.Amount:N0} ل.س) يتجاوز رصيدك المتاح الحالي ({currentBalance:N0} ل.س)"));
            }

            var user = _userManager != null ? await _userManager.GetUserAsync(User) : null;
            var merchantName = !string.IsNullOrWhiteSpace(user?.FullName) ? user.FullName : (!string.IsNullOrWhiteSpace(user?.UserName) ? user.UserName : "التاجر");
            var phone = user?.PhoneNumber ?? "";

            try
            {
                var result = await _settlements.CreateMerchantRequestAsync(uid.Value, merchantName, phone, ownedMerchants,
                    new CreateSettlementRequestDto { Amount = model.Amount, Method = model.Method, AccountDetails = model.AccountDetails.Trim(), Notes = model.Notes });
                var admins = (await _userManager.GetUsersInRoleAsync(AppRoleName.Admin.ToString())).Where(x => x.IsActive).Select(x => x.Id).ToArray();
                if (_notifications != null && admins.Length > 0)
                    await _notifications.SendNewSettlementRequest(admins, result.RequestNumber, merchantName, result.Amount, true);
                return Ok(result);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ApiErr.Create(ex.Message));
            }
        }

        /// <summary>
        /// Get comprehensive financial summary and KPIs for the merchant store
        /// </summary>
        [HttpGet]
        [HttpPost]
        [Route("Summary")]
        public async Task<ActionResult<MerchantFinancialSummaryDto>> GetSummary()
        {
            var uid = User.GetUserId();
            if (!uid.HasValue) return Unauthorized();

            var mids = await _merchantService.GetMerchantIds(uid.Value);
            var position = await _settlements.GetMerchantBalanceAsync(mids);

            var summary = new MerchantFinancialSummaryDto
            {
                CurrentBalance = position.AvailableAmount,
                PendingBalance = position.PendingAmount,
                GrossBalance = position.GrossAmount
            };

            if (mids != null && mids.Length > 0)
            {
                // Align business day with Syrian local time (UTC+3)
                var syriaNow = DateTime.UtcNow.AddHours(3);
                var todayStartUtc = new DateTime(syriaNow.Year, syriaNow.Month, syriaNow.Day, 0, 0, 0, DateTimeKind.Utc).AddHours(-3);
                var monthStartUtc = new DateTime(syriaNow.Year, syriaNow.Month, 1, 0, 0, 0, DateTimeKind.Utc).AddHours(-3);

                var bills = await _billService.Queryable()
                    .AsNoTracking()
                    // A Bill is created when the courier starts shipping, but it
                    // becomes a sale/payable only after successful delivery.
                    // Exclude pickup-time, canceled, and otherwise inactive bills
                    // from merchant sales KPIs.
                    .Where(x => mids.Contains(x.MerchantId) && x.CreatedDate >= monthStartUtc && x.IsAddedToDues)
                    .ToListAsync();

                var todayBills = bills.Where(x => x.CreatedDate >= todayStartUtc).ToList();

                summary.TodayGrossSales = todayBills.Sum(x => x.TotalAmount);
                summary.TodayNetEarnings = todayBills.Sum(x => x.MerchantAmount);
                summary.TodayOrdersCount = todayBills.Count;

                summary.MonthGrossSales = bills.Sum(x => x.TotalAmount);
                summary.MonthNetEarnings = bills.Sum(x => x.MerchantAmount);
                summary.MonthOrdersCount = bills.Count;
            }

            // The settlement workflow is now recorded in the double-entry
            // ledger. Prefer completed settlement requests so this summary does
            // not silently report zero after a real merchant payout. Retain the
            // legacy Payment fallback for historical payouts created before the
            // settlement workflow existed.
            var completedSettlements = await _settlements.GetMineAsync(uid.Value, SettlementPartyType.Merchant);
            var completed = completedSettlements
                .Where(x => x.Status == SettlementRequestStatus.Completed)
                .ToList();
            if (completed.Count > 0)
            {
                summary.TotalPayoutsReceived = completed.Sum(x => x.Amount);
                summary.TotalPayoutsCount = completed.Count;
            }
            else if (_paymentService != null)
            {
                var payments = await _paymentService.Queryable()
                    .AsNoTracking()
                    .Where(x => x.ToUserId == uid.Value && x.HandoverDate != null)
                    .ToListAsync();

                summary.TotalPayoutsReceived = payments.Sum(x => x.Amount);
                summary.TotalPayoutsCount = payments.Count;
            }

            return Ok(summary);
        }

        [HttpGet]
        [Route("SettlementRequests")]
        public async Task<ActionResult<List<SettlementRequestDto>>> SettlementRequests()
        {
            var uid = User.GetUserId();
            if (!uid.HasValue) return Unauthorized();
            return Ok(await _settlements.GetMineAsync(uid.Value, SettlementPartyType.Merchant));
        }

        [HttpPost]
        [Route("SettlementRequests/{id}/ConfirmReceipt")]
        [Route("ConfirmSettlementReceipt/{id}")]
        public async Task<ActionResult<SettlementRequestDto>> ConfirmReceipt(Guid id)
        {
            var uid = User.GetUserId();
            if (!uid.HasValue) return Unauthorized();

            try
            {
                var result = await _settlements.ConfirmMerchantReceiptAsync(id, uid.Value);
                return Ok(result);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ApiErr.Create(ex.Message));
            }
        }
    }

    public class SettlementRequestDto
    {
        [Required(ErrorMessage = "يرجى تحديد المبلغ")]
        public decimal Amount { get; set; }

        [Required(ErrorMessage = "يرجى تحديد طريقة التحويل")]
        public string Method { get; set; }

        [Required(ErrorMessage = "يرجى إدخال تفاصيل الحساب")]
        public string AccountDetails { get; set; }

        public string Notes { get; set; }
    }

    public class MerchantFinancialSummaryDto
    {
        public decimal CurrentBalance { get; set; }
        public decimal PendingBalance { get; set; }
        public decimal GrossBalance { get; set; }
        public decimal TodayGrossSales { get; set; }
        public decimal TodayNetEarnings { get; set; }
        public int TodayOrdersCount { get; set; }
        public decimal MonthGrossSales { get; set; }
        public decimal MonthNetEarnings { get; set; }
        public int MonthOrdersCount { get; set; }
        public decimal TotalPayoutsReceived { get; set; }
        public int TotalPayoutsCount { get; set; }
    }
}
