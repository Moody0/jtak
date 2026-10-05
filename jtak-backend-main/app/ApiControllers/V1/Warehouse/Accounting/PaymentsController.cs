using App.ApiModels;
using App.Shared.Services;
using AutoMapper;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Threading.Tasks;
using System.Data;
using OpenIddict.Validation.AspNetCore;
using Microsoft.AspNetCore.Authorization;
using System.Linq;
using App.Shared.Data.App;
using App.Shared.Services.Extentions;
using App.Shared.Entities.Enums;
using App.Shared.Entities;
using Solf.Models;
using System;
using Modules.Catalog.Services;
using App.Extensions;
using Modules.Shipping.Services;
using Modules.Accounting.Services;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;

namespace App.ApiControllers.V1.Warehouse
{
    [Route("api/v{version:apiVersion}/Warehouse/[controller]")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.MerchantPermission))]
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
            IMapper mapper)
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
        }


        /// <summary>
        /// Get a paged/filtered/Paymented list of Payments
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Route("Mine")]
        public async Task<ActionResult<TableResponseModel<PaymentDto>>> GetMine([FromBody] MetronicTable request)
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
                    HandoverDate = x.HandoverDate,
                    NewBalance = x.NewBalance
                }, x => x.ToUserId == uid.Value && x.Amount > 0);
            return payments;
        }


        [HttpPost]
        [Route("RecivePayment/{id}")]
        public async Task<ActionResult<bool>> RecivePayment(int id)
        {
            var uid = User.GetUserId();
            if (!uid.HasValue)
                return Unauthorized();

            await using var transaction = _auow.Context.Database.IsRelational()
                ? await _auow.Context.Database.BeginTransactionAsync(IsolationLevel.Serializable)
                : null;

            var payment = await _service.Queryable()
                                        .FirstOrDefaultAsync(x => x.Id == id && x.ToUserId == uid);

            if (payment == null)
                return NotFound("The specified payment was not found!");

            // Keep the ledger posting idempotent, but always check it. Older payment
            // rows can already be marked as handed over while missing their ledger
            // entry; returning early here leaves the merchant payable and courier
            // cash custody unreconciled forever.
            var wasAlreadyHandedOver = payment.HandoverDate.HasValue;

            //var deliveryBalance = await _balanceService.GetBalance(payment.ByUserId);
            //var oldDeliveryBalance = deliveryBalance?.Amount ?? 0;
            //var newDeliveryBalance = oldDeliveryBalance - payment.Amount;
            var dUser = await _userManager.Users.Where(x => x.Id == payment.ByUserId).Select(x => x.FullName).FirstOrDefaultAsync();
            var mUser = await _userManager.Users.Where(x => x.Id == payment.ToUserId).Select(x => x.FullName).FirstOrDefaultAsync();

            var mids = await _merchantService.GetMerchantIds(payment.ToUserId);
            var merchantId = mids != null && mids.Length == 1 ? mids[0] : 0;
            if (mids != null && mids.Length > 1)
            {
                // The admin selects one store; its title is stored on the payment. Never guess the store
                // for an owner with several stores - that would credit the wrong merchant account.
                var matches = await _merchantService.Queryable().AsNoTracking()
                    .Where(m => mids.Contains(m.Id) && m.Title == payment.ToUser).Select(m => m.Id).Take(2).ToListAsync();
                if (matches.Count != 1)
                {
                    if (transaction != null) await transaction.RollbackAsync();
                    return BadRequest(ApiErr.Create("تعذر تحديد المتجر المقصود بهذه الدفعة. تواصل مع الإدارة."));
                }
                merchantId = matches[0];
            }

            if (merchantId > 0)
            {
                await _ledgerService.PostCaptainToMerchantPaymentAsync(
                    payment.ByUserId,
                    merchantId,
                    payment.Amount,
                    $"Payment-{payment.Id}",
                    dUser,
                    mUser);
            }
            else
            {
                await _ledgerService.PostCaptainCashHandoverAsync(
                    payment.ByUserId,
                    payment.Amount,
                    $"Payment-{payment.Id}",
                    dUser);
            }

            if (!wasAlreadyHandedOver)
            {
                var oldMerchantBalance = (await _balanceService.GetBalance(payment.ToUserId))?.Amount ?? 0;

                payment.HandoverDate = DateTime.UtcNow;
                payment.NewBalance = merchantId > 0
                    ? Math.Max(0m, await _ledgerService.GetMerchantPayableBalanceAsync(merchantId))
                    : Math.Max(0m, oldMerchantBalance - payment.Amount);

                // Update legacy balance mirrors only on the first confirmation. The
                // ledger service above uses Payment-{id} as its idempotency key.
                await _balanceService.DecreaseAppBalance(payment.ByUserId, payment.Amount, dUser);
                await _balanceService.DecreaseAppBalance(payment.ToUserId, payment.Amount, mUser);
            }

            await _auow.SaveChangesAsync();
            if (transaction != null) await transaction.CommitAsync();
            if (!wasAlreadyHandedOver)
                await _notificationService.SendPaymentRecived(new[] { payment.ByUserId }, payment.Id, payment.Amount);

            return true;
        }
    }
}
