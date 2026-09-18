using App.ApiModels;
using Microsoft.AspNetCore.Mvc;
using System.Threading.Tasks;
using OpenIddict.Validation.AspNetCore;
using Microsoft.AspNetCore.Authorization;
using Modules.Catalog.Services;
using App.Shared.Entities.Enums;
using App.Shared.Entities;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Modules.Orders.Services;
using Modules.Orders.Entities;
using Modules.Accounting.Services;
using App.Shared.Services.eCommerce;
using System.Linq;

namespace App.ApiControllers.V1.Admin
{
    [Route("api/v{version:apiVersion}/Admin/[controller]")]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.AdminPermission))]
    public class DashboardController : SolApiController
    {
        private readonly IProductService _service;
        private readonly IOrderService _orderService;
        private readonly IOrderDetailService _orderDetailsService;
        private readonly IBillService _billService;
        private readonly UserManager<AppUser> _userManager;

        public DashboardController(IProductService service,
            IOrderService orderService,
            IOrderDetailService orderDetailsService,
            IBillService billService,
            UserManager<AppUser> userManager)
        {
            _service = service;
            _orderService = orderService;
            _orderDetailsService = orderDetailsService;
            _userManager = userManager;
            _billService = billService;
        }

        /// <summary>
        /// Get dashboard stats
        /// </summary>
        /// <returns></returns>
        [HttpGet]
        public async Task<ActionResult<DashboardVm>> Get()
        {
            var topProds = await _orderDetailsService.Queryable().AsNoTracking()
                                                    .Where(x => x.OrderDetailStatus == OrderDetailStatus.Delivered)
                                                    .GroupBy(x => x.ProductId)
                                                    .Select(x => new TopProduct
                                                    {
                                                        ProductId = x.Key,
                                                        Count = x.Sum(x => x.Quantity)
                                                    })
                                                    .OrderByDescending(x => x.Count)
                                                    .Take(30)
                                                    .ToArrayAsync();

            // Resolve the titles in one round trip instead of a lookup per row.
            // A best seller that has since been deactivated or deleted has no
            // title to show, but it must not take the whole dashboard down.
            var topProdIds = topProds.Select(x => x.ProductId).ToArray();
            var titles = await _service.Queryable().AsNoTracking()
                                       .Where(x => topProdIds.Contains(x.Id))
                                       .Select(x => new { x.Id, x.Title })
                                       .ToDictionaryAsync(x => x.Id, x => x.Title);
            foreach (var prod in topProds)
            {
                prod.ProductName = titles.TryGetValue(prod.ProductId, out var title) ? title : string.Empty;
            }

            return new DashboardVm
            {
                ProductsCount = await _service.Queryable().AsNoTracking()
                                          .CountAsync(x => x.DeletionDate == null && x.Active),
                UsersCount = await _userManager.Users.AsNoTracking().CountAsync(x => x.IsActive),
                OrdersCount = await _orderService.Queryable().AsNoTracking().CountAsync(x => x.OrderStatus == OrderStatus.Success),
                BillsCount = await _billService.Queryable().AsNoTracking().CountAsync(),
                TotalOrdersValue = ToAmount(await _billService.Queryable().AsNoTracking().SumAsync(x => (decimal?)x.TotalAmount)),
                JTakOrdersValue = ToAmount(await _billService.Queryable().AsNoTracking().SumAsync(x => (decimal?)x.JTakAmount)),
                JTakAdditionalOrdersValue = ToAmount(await _billService.Queryable().AsNoTracking().SumAsync(x => (decimal?)x.JTakAdditionalAmount)),
                MerchantOrdersValue = ToAmount(await _billService.Queryable().AsNoTracking().SumAsync(x => (decimal?)x.MerchantAmount)),
                TopProducts = topProds

            };
        }

        /// <summary>
        /// Narrows a summed money column down to the whole number the dashboard
        /// displays. Clamping keeps one corrupt row from turning the request
        /// into an OverflowException.
        /// </summary>
        private static long ToAmount(decimal? value)
        {
            var amount = value ?? 0m;
            if (amount >= long.MaxValue) return long.MaxValue;
            if (amount <= long.MinValue) return long.MinValue;
            return (long)amount;
        }
    }
}
