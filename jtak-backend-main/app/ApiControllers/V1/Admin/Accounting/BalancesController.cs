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
using Modules.Catalog.Entities;
using Microsoft.EntityFrameworkCore;
using System.Linq;
using Solf.Identity;
using URF.Core.Abstractions.Trackable;

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

        private readonly RoleManager<SolRole> _roleManager;
        private readonly ITrackableRepository<SolUserRole> _userRoleRepo;

        public BalancesController(IAppUnitOfWork unitOfWork,
            IAccountingUnitOfWork auow,
            INotificationService notificationService,
            UserManager<AppUser> userManager,
            RoleManager<SolRole> roleManager,
            ITrackableRepository<SolUserRole> userRoleRepo,
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
            _roleManager = roleManager;
            _userRoleRepo = userRoleRepo;
            _notificationService = notificationService;
            _mapper = mapper;
            _merchantService = merchantService;
            _deliveryService = deliveryService;
            _service = service;
            //_billService = billService;
            _balanceService = balanceService;
        }


        /// <summary>
        /// Get a paged/filtered list of Merchant Balances for the Admin Dashboard
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Route("DataTable")]
        public async Task<ActionResult<TableResponseModel<BalanceDto>>> DataTable([FromBody] MetronicTable request)
        {
            var query = _merchantService.Queryable().AsNoTracking()
                .Where(x => x.DeletionDate == null && x.Active);

            if (!string.IsNullOrWhiteSpace(request?.Search))
            {
                var search = request.Search.Trim();
                query = query.Where(x =>
                    x.Title.Contains(search) ||
                    (x.OwnerName != null && x.OwnerName.Contains(search)) ||
                    (x.Phone1 != null && x.Phone1.Contains(search)) ||
                    (x.Phone2 != null && x.Phone2.Contains(search)) ||
                    x.Id.ToString() == search);
            }

            var total = await query.CountAsync();

            var pageNumber = request?.PageNumber ?? 1;
            var pageSize = request?.PageSize ?? 10;
            if (pageSize <= 0) pageSize = 10;
            if (pageNumber <= 0) pageNumber = 1;

            var merchants = await query
                .OrderBy(x => x.Title)
                .Skip((pageNumber - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync();

            var merchantIds = merchants.Select(m => m.Id).ToList();

            // Liability account for vendor payable (2010-VND-): normal balance is Credit - Debit
            var ledgerBalances = await _auow.Context.Accounts.AsNoTracking()
                .Where(a => a.OwnerMerchantId != null &&
                            merchantIds.Contains(a.OwnerMerchantId.Value) &&
                            a.Type == AccountType.Liability &&
                            a.AccountCode.StartsWith(SystemAccountCodes.VendorPayablePrefix))
                .Select(a => new
                {
                    MerchantId = a.OwnerMerchantId.Value,
                    Balance = a.LedgerEntries.Sum(e => e.Credit - e.Debit)
                })
                .ToDictionaryAsync(x => x.MerchantId, x => x.Balance);

            var dtos = merchants.Select(m => new BalanceDto
            {
                Id = m.OwnerId != Guid.Empty ? m.OwnerId : Guid.NewGuid(),
                EntityId = m.Id,
                Name = m.Title,
                Phone = !string.IsNullOrWhiteSpace(m.Phone1) ? m.Phone1 : m.Phone2,
                Amount = ledgerBalances.TryGetValue(m.Id, out var bal) ? bal : 0m,
                PendingAmount = 0m,
                CreatedDate = m.CreatedDate
            }).ToList();

            return new TableResponseModel<BalanceDto>
            {
                Items = dtos.ToArray(),
                TotalRecords = total
            };
        }

        /// <summary>
        /// Get a paged/filtered list of Delivery Driver Balances (Cash custody &amp; earnings) for the Admin Dashboard
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Route("Drivers/DataTable")]
        public async Task<ActionResult<TableResponseModel<BalanceDto>>> DriversDataTable([FromBody] MetronicTable request)
        {
            var driverRoleIds = await _roleManager.Roles.AsNoTracking()
                .Where(r => r.NormalizedName == "DELIVERY" || r.NormalizedName == "DRIVER" || r.NormalizedName == "CAPTAIN")
                .Select(r => r.Id)
                .ToListAsync();

            if (!driverRoleIds.Any())
            {
                var deliveryRole = await _roleManager.FindByNameAsync("Delivery");
                if (deliveryRole != null)
                {
                    driverRoleIds.Add(deliveryRole.Id);
                }
            }

            if (!driverRoleIds.Any())
            {
                return new TableResponseModel<BalanceDto>
                {
                    Items = Array.Empty<BalanceDto>(),
                    TotalRecords = 0
                };
            }

            var allDriverUserIds = await _userRoleRepo.Queryable().AsNoTracking()
                .Where(ur => driverRoleIds.Contains(ur.RoleId))
                .Select(ur => ur.UserId)
                .Distinct()
                .ToListAsync();

            if (!allDriverUserIds.Any())
            {
                return new TableResponseModel<BalanceDto>
                {
                    Items = Array.Empty<BalanceDto>(),
                    TotalRecords = 0
                };
            }

            var query = _userManager.Users.AsNoTracking()
                .Where(u => allDriverUserIds.Contains(u.Id) && u.DeletionDate == null && u.IsActive);

            if (!string.IsNullOrWhiteSpace(request?.Search))
            {
                var s = request.Search.Trim();
                query = query.Where(u =>
                    (u.FullName != null && u.FullName.Contains(s)) ||
                    (u.FirstName != null && u.FirstName.Contains(s)) ||
                    (u.LastName != null && u.LastName.Contains(s)) ||
                    (u.PhoneNumber != null && u.PhoneNumber.Contains(s)) ||
                    (u.Email != null && u.Email.Contains(s)));
            }

            var total = await query.CountAsync();

            var pageNumber = request?.PageNumber ?? 1;
            var pageSize = request?.PageSize ?? 10;
            if (pageSize <= 0) pageSize = 10;
            if (pageNumber <= 0) pageNumber = 1;

            var drivers = await query
                .OrderBy(u => u.FullName ?? u.UserName)
                .Skip((pageNumber - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync();

            var pagedDriverUserIds = drivers.Select(d => d.Id).ToList();

            // Captain Cash Float accounts (1010-CAP-): Asset account, Normal balance = Debit - Credit
            var floatBalances = await _auow.Context.Accounts.AsNoTracking()
                .Where(a => a.OwnerUserId != null &&
                            pagedDriverUserIds.Contains(a.OwnerUserId.Value) &&
                            a.Type == AccountType.Asset &&
                            a.AccountCode.StartsWith(SystemAccountCodes.CaptainCashFloatPrefix))
                .Select(a => new
                {
                    UserId = a.OwnerUserId.Value,
                    Balance = a.LedgerEntries.Sum(e => e.Debit - e.Credit)
                })
                .ToDictionaryAsync(x => x.UserId, x => x.Balance);

            // Captain Earnings / Wages accounts (2020-CAP-): Liability account, Normal balance = Credit - Debit
            var wageBalances = await _auow.Context.Accounts.AsNoTracking()
                .Where(a => a.OwnerUserId != null &&
                            pagedDriverUserIds.Contains(a.OwnerUserId.Value) &&
                            a.Type == AccountType.Liability &&
                            a.AccountCode.StartsWith(SystemAccountCodes.CaptainEarningsPrefix))
                .Select(a => new
                {
                    UserId = a.OwnerUserId.Value,
                    Balance = a.LedgerEntries.Sum(e => e.Credit - e.Debit)
                })
                .ToDictionaryAsync(x => x.UserId, x => x.Balance);

            var dtos = drivers.Select(d => new BalanceDto
            {
                Id = d.Id,
                Name = !string.IsNullOrWhiteSpace(d.FullName) ? d.FullName : $"{d.FirstName} {d.LastName}".Trim(),
                Phone = d.PhoneNumber,
                Amount = floatBalances.TryGetValue(d.Id, out var fb) ? fb : 0m,
                WagesAmount = wageBalances.TryGetValue(d.Id, out var wb) ? wb : 0m,
                PendingAmount = 0m,
                CreatedDate = d.CreatedDate
            }).ToList();

            return new TableResponseModel<BalanceDto>
            {
                Items = dtos.ToArray(),
                TotalRecords = total
            };
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
