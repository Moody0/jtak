using App.ApiModels;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using System.Threading.Tasks;
using OpenIddict.Validation.AspNetCore;
using Microsoft.AspNetCore.Authorization;
using App.Shared.Entities.Enums;
using App.Extensions;
using Modules.Accounting.Services;
using Modules.Accounting.Entities;

namespace App.ApiControllers.V1.Warehouse
{
    [Route("api/v{version:apiVersion}/Warehouse/[controller]")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.MerchantPermission))]
    public class BalancesController : SolApiController
    {
        private readonly IBalanceService _service;

        public BalancesController(IBalanceService service)
        {
            _service = service;
        }


        /// <summary>
        /// Get my Balance
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Route("Mine")]
        public async Task<ActionResult<BalanceDto>> GetMine() =>
            await _service.GetBalance(User.GetUserId().Value);
    }
}
