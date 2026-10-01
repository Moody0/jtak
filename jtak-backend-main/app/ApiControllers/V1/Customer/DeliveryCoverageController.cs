using System;
using System.Threading.Tasks;
using App.Shared.Services;
using App.ApiModels;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace App.ApiControllers.V1.Customer;

[ApiController]
[ApiVersion("1")]
[Route("api/v{version:apiVersion}/Customer/[controller]")]
[AllowAnonymous]
public class DeliveryCoverageController : SolApiController
{
    private readonly HomsCoverageService _coverage;
    public DeliveryCoverageController(HomsCoverageService coverage) => _coverage = coverage;
    [HttpGet]
    public async Task<IActionResult> Get()
    {
        Response.Headers.CacheControl = "no-store";
        try { return Ok(await _coverage.GetSettingAsync()); }
        catch (InvalidOperationException ex) { return BadRequest(ApiErr.Create(ex.Message)); }
    }
    [HttpPost("Check")]
    public async Task<IActionResult> Check([FromBody] CoverageCheck request)
    {
        if (request == null) return BadRequest();
        try {
            var error = await _coverage.ValidateAsync(request.DeliveryLat, request.DeliveryLng);
            return error == null ? Ok(new { eligible = true }) : BadRequest(ApiErr.Create(error));
        } catch (InvalidOperationException ex) { return BadRequest(ApiErr.Create(ex.Message)); }
    }
    public class CoverageCheck {
        public decimal DeliveryLat { get; set; }
        public decimal DeliveryLng { get; set; }
    }
}
