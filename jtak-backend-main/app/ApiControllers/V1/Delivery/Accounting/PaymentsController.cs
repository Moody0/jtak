using App.ApiModels;
using App.Shared.Services;
using AutoMapper;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using System.Threading.Tasks;
using OpenIddict.Validation.AspNetCore;
using Microsoft.AspNetCore.Authorization;
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

namespace App.ApiControllers.V1.Delivery
{
    [Route("api/v{version:apiVersion}/Delivery/[controller]")]
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

        public PaymentsController(IAppUnitOfWork unitOfWork,
            IAccountingUnitOfWork auow,
            INotificationService notificationService,
            UserManager<AppUser> userManager,
            IMerchantService merchantService,
            IDeliveryService deliveryService,
            IPaymentService service,
            IBillService billService,
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
                }, x => x.ByUserId == uid.Value);
            return payments;
        }
    }
}
