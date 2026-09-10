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
            // Create new payment
            var byUser = await _userManager.Users.Where(x => x.Id == dto.ByUserId).Select(x => x.FullName).FirstOrDefaultAsync();
            var toUser = await _userManager.Users.Where(x => x.Id == dto.ToUserId).Select(x => x.FullName).FirstOrDefaultAsync();
            var dBalance = await _balanceService.GetBalance(dto.ByUserId);
            //var oldBalance = dBalance?.Amount ?? 0;
            //var newBalance = oldBalance - dto.Amount;
            var newBalance = dto.Amount;
            var payment = new Payment
            {
                ByUserId = dto.ByUserId,
                ByUser = byUser,
                ToUserId = dto.ToUserId,
                ToUser = toUser,
                NewBalance = newBalance,
                Amount = dto.Amount
            };
            _service.Insert(payment);

            // Update delivery user balance
            await _balanceService.UpdateAppBalance(new BalanceDto { Amount = newBalance, PendingAmount = dBalance.PendingAmount, Id = dto.ByUserId, Name = byUser });
            await _uow.SaveChangesAsync();
            return true;
        }
    }
}
