using App.ApiModels;
using App.Shared.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using System.Threading.Tasks;
using App.Shared.Entities.Domain;

namespace App.ApiControllers.V1.Customer
{
    [Route("api/v{version:apiVersion}/Customer/[controller]")]
    [Route("api/v{version:apiVersion}/Customer/Banners")]
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
        /// Get Banners by location
        /// </summary>
        [HttpGet]
        [Route("")]
        [Route("{location}")]
        public async Task<ActionResult<BannerLiteDto[]>> GetAll([FromRoute] BannerLocation? location, [FromQuery] BannerLocation? loc)
        {
            var target = location ?? loc;
            if (target.HasValue)
            {
                return await _service.GetBanners(target.Value);
            }
            return await _service.GetAllActiveBanners();
        }

        /// <summary>
        /// Get all active banners across all placements
        /// </summary>
        [HttpGet]
        [Route("All")]
        public async Task<ActionResult<BannerLiteDto[]>> GetAllActive() =>
            await _service.GetAllActiveBanners();
    }
}
