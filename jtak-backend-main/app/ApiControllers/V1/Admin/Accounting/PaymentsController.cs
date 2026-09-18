using App.ApiModels;
using App.Shared.Services;
using AutoMapper;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Threading.Tasks;
using System;
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
            var uid = User.GetUserId();
            var payments = await _service.ListMetronicTableQueryable(request,
                x => new PaymentDto
                {
                    Id = x.Id,
                    Amount = x.Amount,
                    ByUser = x.ByUser,
                    ByUserId = x.ByUserId,
                    ToUser = x.ToUser,
                    ToUserId = x.ToUserId,
                    CreatedDate = x.CreatedDate,
                    HandoverDate = x.HandoverDate,
                    NewBalance = x.NewBalance
                });
            return payments;
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

                await _ledgerService.PostCaptainCashHandoverAsync(dto.ByUserId, dto.Amount, $"Payment-{payment.Id}", byUser);

                // Keep the legacy balance as a compatibility mirror while the
                // ledger remains the source of truth for current app screens.
                await _balanceService.UpdateAppBalance(new BalanceDto { Amount = newBalance, PendingAmount = dBalance.PendingAmount, Id = dto.ByUserId, Name = byUser });
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
    }
}
