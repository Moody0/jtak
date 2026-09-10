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
using System;
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
    public class BalancesController : SolApiController
    {
        private readonly IAppUnitOfWork _uow;
        private readonly IAccountingUnitOfWork _auow;
        private readonly INotificationService _notificationService;
        private readonly UserManager<AppUser> _userManager;
        private readonly IMapper _mapper;
        private readonly IMerchantService _merchantService;
        private readonly IDeliveryService _deliveryService;
        private readonly IBalanceService _service;
        //private readonly IBillService _billService;
        private readonly IBalanceService _balanceService;

        public BalancesController(IAppUnitOfWork unitOfWork,
            IAccountingUnitOfWork auow,
            INotificationService notificationService,
            UserManager<AppUser> userManager,
            IMerchantService merchantService,
            IDeliveryService deliveryService,
            IBalanceService service,
            //IBillService billService,
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
            //_billService = billService;
            _balanceService = balanceService;
        }


        /// <summary>
        /// Get a paged/filtered/Balanceed list of Balances
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Route("DataTable")]
        public async Task<ActionResult<TableResponseModel<BalanceDto>>> DataTable([FromBody] MetronicTable request)
        {
            var uid = User.GetUserId();
            var Balances = await _service.ListMetronicTableQueryable(request,
                x => new BalanceDto
                {
                    Id = x.Id,
                    Name = x.Name,
                    Amount = x.Amount
                });
            return Balances;
        }

        //[HttpPut]
        //[Route("{id}")]
        //public async Task<ActionResult<bool>> Set(Guid id, BalanceDto dto)
        //{
        //    // Create new Balance
        //    var byUser = await _userManager.Users.Where(x => x.Id == dto.ByUserId).Select(x => x.FullName).FirstOrDefaultAsync();
        //    var toUser = await _userManager.Users.Where(x => x.Id == dto.ToUserId).Select(x => x.FullName).FirstOrDefaultAsync();
        //    var balance = await _balanceService.GetBalance(dto.ByUserId);
        //    var oldBalance = balance?.Amount ?? 0;
        //    var newBalance = oldBalance - dto.Amount;
        //    var Balance = new Balance { ByUserId = dto.ByUserId, ByUser = dto.ByUser, ToUserId = dto.ToUserId, ToUser = dto.ToUser, NewBalance = oldBalance, Amount = dto.Amount };
        //    _service.Insert(Balance);
        //
        //    // Update delivery user balance
        //    await _balanceService.UpdateBalance(new BalanceDto { Amount = newBalance, PendingAmount = balance.PendingAmount, Id = dto.ByUserId });
        //    await _uow.SaveChangesAsync();
        //    return true;
        //}

        [HttpGet]
        [Route("{id}")]
        public async Task<ActionResult<BalanceDto>> Get(Guid id) =>
            await _balanceService.GetBalance(id);

    }
}
