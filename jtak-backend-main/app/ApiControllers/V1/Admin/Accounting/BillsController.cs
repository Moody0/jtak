using App.ApiModels;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Threading.Tasks;
using OpenIddict.Validation.AspNetCore;
using Microsoft.AspNetCore.Authorization;
using App.Shared.Entities.Enums;
using Solf.Models;
using Modules.Catalog.Services;
using App.Extensions;
using Modules.Accounting.Services;
using Modules.Accounting.Entities;

namespace App.ApiControllers.V1.Admin
{
    [Route("api/v{version:apiVersion}/Admin/[controller]")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.DeliveryPermission))]
    public class BillsController : SolApiController
    {
        private readonly IMerchantService _merchantService;
        private readonly IBillService _service;

        public BillsController(
            IMerchantService merchantService,
            IBillService service)
        {
            _merchantService = merchantService;
            _service = service;
        }


        /// <summary>
        /// Get a paged/filtered/Billed list of Bills
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Route("DataTable")]
        public async Task<ActionResult<TableResponseModel<BillDto>>> DataTable([FromBody] MetronicTable request)
        {
            var uid = User.GetUserId();
            var merchants = await _merchantService.Queryable().ToDictionaryAsync(x => x.Id, x => x.Title);
            var Bills = await _service.ListMetronicTableQueryable(request,
                x => new BillDto
                {
                    Id = x.Id,
                    OrderId = x.OrderId,
                    MerchantId = x.MerchantId,
                    MerchantTitle = merchants[x.MerchantId],
                    PaymentMethod = x.PaymentMethod,
                    MerchantAmount = x.MerchantAmount,
                    JTakAdditionalAmount = x.JTakAdditionalAmount,
                    JTakAmount = x.JTakAmount,
                    TotalAmount = x.TotalAmount,
                    CreatedDate = x.CreatedDate,
                    DueDate = x.DueDate,
                    IsAddedToDues = x.IsAddedToDues
                });
            return Bills;
        }
    }
}
