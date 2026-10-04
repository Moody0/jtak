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
using System.Linq;

namespace App.ApiControllers.V1.Admin
{
    [Route("api/v{version:apiVersion}/Admin/[controller]")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.AdminPermission))]
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
        /// Get a paged/filtered/sorted list of Bills
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Route("DataTable")]
        public async Task<ActionResult<TableResponseModel<BillDto>>> DataTable([FromBody] MetronicTable request, [FromQuery] string duesStatus = "all")
        {
            var merchantsList = await _merchantService.Queryable()
                .AsNoTracking()
                .Select(m => new { m.Id, m.Title })
                .ToListAsync();

            var merchants = merchantsList
                .GroupBy(x => x.Id)
                .ToDictionary(g => g.Key, g => g.First().Title ?? string.Empty);

            bool? added = duesStatus == "added" ? true : duesStatus == "pending" ? false : null;
            var bills = await _service.GetDataTableAsync(request, merchants, null, added);
            var summary = await _service.GetSummaryAsync(request, merchants, added);
            return Ok(new { bills.Items, bills.TotalRecords, bills.TotalRecordsFiltered, Summary = summary });
        }
    }
}
