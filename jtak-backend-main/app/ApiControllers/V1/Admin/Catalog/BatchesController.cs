using App.ApiModels;
using App.Extensions;
using App.Shared.Entities;
using App.Shared.Entities.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Modules.Catalog.Entities;
using Modules.Catalog.Services;
using Microsoft.EntityFrameworkCore;
using OpenIddict.Validation.AspNetCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace App.ApiControllers.V1.Admin
{
    [Route("api/v{version:apiVersion}/Admin/[controller]")]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.AdminPermission))]
    public class BatchesController : SolApiController
    {
        private readonly IInventoryBatchService _batchService;
        private readonly IMerchantService _merchantService;
        private readonly ILogger _logger;

        public BatchesController(
            IInventoryBatchService batchService,
            IMerchantService merchantService,
            ILogger<BatchesController> logger)
        {
            _batchService = batchService ?? throw new ArgumentNullException(nameof(batchService));
            _merchantService = merchantService ?? throw new ArgumentNullException(nameof(merchantService));
            _logger = logger;
        }

        /// <summary>
        /// Get batches filtered by merchant, product, status, or search term (FEFO sorted)
        /// </summary>
        [HttpGet]
        public async Task<ActionResult<List<ProductBatchDto>>> Get(
            [FromQuery] int? merchantId = null,
            [FromQuery] int? productId = null,
            [FromQuery] BatchStatus? status = null,
            [FromQuery] string searchTerm = null)
        {
            var batches = await _batchService.GetAllBatchesAsync(merchantId, productId, status, searchTerm);
            return Ok(batches);
        }

        /// <summary>
        /// Get warehouse inventory KPI metrics
        /// </summary>
        [HttpGet("Kpis")]
        public async Task<ActionResult<InventoryBatchKpiDto>> GetKpis([FromQuery] int? merchantId = null)
        {
            var kpis = await _batchService.GetBatchKpisAsync(merchantId);
            return Ok(kpis);
        }

        /// <summary>
        /// Fast product lookup for batch intake autocomplete
        /// </summary>
        [HttpGet("Lookup/Products")]
        public async Task<ActionResult<List<BatchProductLookupDto>>> LookupProducts(
            [FromQuery] string search = null,
            [FromQuery] int? merchantId = null)
        {
            var items = await _batchService.GetProductLookupAsync(search, merchantId);
            return Ok(items);
        }

        /// <summary>
        /// Merchant / Warehouse lookup for filters and intake
        /// </summary>
        [HttpGet("Lookup/Merchants")]
        public async Task<ActionResult<List<BatchMerchantLookupDto>>> LookupMerchants()
        {
            var items = await _batchService.GetMerchantLookupAsync();
            return Ok(items);
        }

        /// <summary>
        /// Toggle batch quarantine status
        /// </summary>
        [HttpPost("{id:int}/Quarantine")]
        public async Task<ActionResult<ProductBatchDto>> ToggleQuarantine(int id, [FromBody] QuarantineBatchDto dto)
        {
            var userName = User.Identity?.Name ?? "Admin";
            var updated = await _batchService.ToggleQuarantineAsync(id, dto?.Quarantine ?? true, dto?.Reason, userName);
            return Ok(updated);
        }

        /// <summary>
        /// Get near-expiry or expired batch alerts across warehouses
        /// </summary>
        [HttpGet("Alerts")]
        public async Task<ActionResult<List<ProductBatchDto>>> GetAlerts([FromQuery] int? merchantId = null, [FromQuery] int daysThreshold = 7)
        {
            var alerts = await _batchService.GetAllAlertsAsync(merchantId, daysThreshold);
            return Ok(alerts);
        }

        /// <summary>
        /// Get batch details by ID
        /// </summary>
        [HttpGet("{id:int}")]
        public async Task<ActionResult<ProductBatchDto>> GetById(int id)
        {
            var batch = await _batchService.GetBatchByIdAsync(id);
            if (batch == null) return NotFound();
            return Ok(batch);
        }

        /// <summary>
        /// Admin stock batch intake
        /// </summary>
        [HttpPost]
        public async Task<ActionResult<ProductBatchDto>> Create([FromBody] CreateProductBatchDto dto)
        {
            if (dto == null) return BadRequest("Invalid batch payload.");
            var userName = User.Identity?.Name ?? "Admin";
            var created = await _batchService.CreateBatchAsync(dto, userName);

            return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
        }

        /// <summary>
        /// Admin inventory recount or damage adjustment
        /// </summary>
        [HttpPost("Adjust")]
        public async Task<ActionResult<ProductBatchDto>> AdjustStock([FromBody] StockAdjustmentDto dto)
        {
            if (dto == null) return BadRequest("Invalid adjustment payload.");
            var userName = User.Identity?.Name ?? "Admin";
            var updated = await _batchService.AdjustStockAsync(dto, userName);

            return Ok(updated);
        }
    }
}
