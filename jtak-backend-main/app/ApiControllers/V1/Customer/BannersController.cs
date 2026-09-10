using App.ApiModels;
using App.Shared.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using System.Threading.Tasks;
using App.Shared.Entities.Domain;

namespace App.ApiControllers.V1.Customer
{
    [Route("api/v{version:apiVersion}/Customer/[controller]")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [ApiVersion("1")]
    public class BannerController : SolApiController
    {
        private readonly IBannerService _service;

        public BannerController(IBannerService service)
        {
            _service = service;
        }

        /// <summary>
        /// Get All Banneres
        /// </summary>
        /// <returns></returns>
        [HttpGet]
        [Route("{location}")]
        public async Task<ActionResult<BannerLiteDto[]>> GetAll(BannerLocation location = BannerLocation.HomePage) =>
            await _service.GetBanners(location);

    }
}
