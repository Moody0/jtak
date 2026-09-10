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
                                                        //ProductName = x.FirstOrDefault(p => p.ProductTitle != null).ProductTitle,
                                                        Count = x.Sum(x => x.Quantity)
                                                    })
                                                    .OrderByDescending(x => x.Count)
                                                    .Take(30)
                                                    .ToArrayAsync();
            foreach (var prod in topProds)
            {
                prod.ProductName = (await _service.GetProduct(prod.ProductId)).Title;
            }
            return new DashboardVm
            {
                ProductsCount = await _service.Queryable().AsNoTracking()
                                          .CountAsync(x => x.Active),
                UsersCount = await _userManager.Users.AsNoTracking().CountAsync(x => x.IsActive),
                OrdersCount = await _orderService.Queryable().AsNoTracking().CountAsync(x => x.OrderStatus == OrderStatus.Success),
                BillsCount = await _billService.Queryable().AsNoTracking().CountAsync(),
                TotalOrdersValue = (int)await _billService.Queryable().AsNoTracking().SumAsync(x => x.TotalAmount),
                JTakOrdersValue = (int)await _billService.Queryable().AsNoTracking().SumAsync(x => x.JTakAmount),
                JTakAdditionalOrdersValue = (int)await _billService.Queryable().AsNoTracking().SumAsync(x => x.JTakAdditionalAmount),
                MerchantOrdersValue = (int)await _billService.Queryable().AsNoTracking().SumAsync(x => x.MerchantAmount),
                TopProducts = topProds

            };
        }
    }
}
