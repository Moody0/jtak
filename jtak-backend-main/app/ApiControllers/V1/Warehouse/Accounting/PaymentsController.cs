using App.ApiModels;
using App.Shared.Services;
using AutoMapper;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Threading.Tasks;
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

        public PaymentsController(IAppUnitOfWork unitOfWork,
            IAccountingUnitOfWork auow,
            INotificationService notificationService,
            UserManager<AppUser> userManager,
            IMerchantService merchantService,
            IDeliveryService deliveryService,
            IPaymentService service,
            IBillService billService,
            IBalanceService balanceService,
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
            var payment = await _service.Queryable()
                                        .FirstOrDefaultAsync(x => x.Id == id && x.ToUserId == uid);

            if (payment == null)
                return NotFound("The specified payment was not found!");

            //var deliveryBalance = await _balanceService.GetBalance(payment.ByUserId);
            //var oldDeliveryBalance = deliveryBalance?.Amount ?? 0;
            //var newDeliveryBalance = oldDeliveryBalance - payment.Amount;
            var dUser = await _userManager.Users.Where(x => x.Id == payment.ByUserId).Select(x => x.FullName).FirstOrDefaultAsync();

            var oldMerchantBalance = (await _balanceService.GetBalance(payment.ToUserId))?.Amount ?? 0;
            var mUser = await _userManager.Users.Where(x => x.Id == payment.ToUserId).Select(x => x.FullName).FirstOrDefaultAsync();

            payment.HandoverDate = DateTime.UtcNow;
            payment.NewBalance = oldMerchantBalance + payment.Amount;

            // Update delivery and warehouse user balances
            await _balanceService.DecreaseAppBalance(payment.ByUserId, payment.Amount, dUser); // VERIFIED
            await _balanceService.IncreaseAppBalance(payment.ToUserId, payment.Amount, mUser); // VERIFIED

            await _notificationService.SendPaymentRecived(new[] { payment.ByUserId }, payment.Id, payment.Amount);

            return true;
        }
    }
}
