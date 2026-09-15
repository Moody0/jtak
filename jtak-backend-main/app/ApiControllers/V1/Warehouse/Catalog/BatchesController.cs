using App.ApiModels;
using App.Extensions;
using App.Shared.Entities;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Modules.Catalog.Entities;
using Modules.Catalog.Services;
using OpenIddict.Validation.AspNetCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

using App.Shared.Entities.Enums;

namespace App.ApiControllers.V1.Warehouse.Catalog
{
    [Route("api/v{version:apiVersion}/Warehouse/[controller]")]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.MerchantPermission))]
    public class BatchesController : SolApiController
    {
        private readonly IInventoryBatchService _batchService;
        private readonly IMerchantService _merchantService;
        private readonly UserManager<AppUser> _userManager;
        private readonly ILogger _logger;

        public BatchesController(
            IInventoryBatchService batchService,
            IMerchantService merchantService,
            UserManager<AppUser> userManager,
            ILogger<BatchesController> logger)
        {
            _batchService = batchService ?? throw new ArgumentNullException(nameof(batchService));
            _merchantService = merchantService ?? throw new ArgumentNullException(nameof(merchantService));
            _userManager = userManager ?? throw new ArgumentNullException(nameof(userManager));
            _logger = logger;
        }

        /// <summary>
        /// Get all batches belonging to the logged-in merchant's warehouse
        /// </summary>
        [HttpGet]
        public async Task<ActionResult<List<ProductBatchDto>>> Get([FromQuery] int? productId = null, [FromQuery] BatchStatus? status = null)
        {
            var userId = User.GetUserId();
            if (!userId.HasValue) return Unauthorized();

            var merchantIds = await _merchantService.GetMerchantIds(userId.Value);
            if (!merchantIds.Any())
                return Ok(new List<ProductBatchDto>());

            var results = new List<ProductBatchDto>();
            foreach (var mid in merchantIds)
            {
                if (productId.HasValue)
                {
                    var batches = await _batchService.GetBatchesByProductAsync(productId.Value, mid);
                    if (status.HasValue)
                        batches = batches.Where(b => b.Status == status.Value).ToList();
                    results.AddRange(batches);
                }
                else
                {
                    var batches = await _batchService.GetBatchesByMerchantAsync(mid, status);
                    results.AddRange(batches);
                }
            }

            return Ok(results);
        }

        /// <summary>
        /// Get batches approaching expiry or already expired for alerts
        /// </summary>
        [HttpGet("Alerts")]
        public async Task<ActionResult<List<ProductBatchDto>>> GetAlerts([FromQuery] int daysThreshold = 7)
        {
            var userId = User.GetUserId();
            if (!userId.HasValue) return Unauthorized();

            var merchantIds = await _merchantService.GetMerchantIds(userId.Value);
            var results = new List<ProductBatchDto>();

            foreach (var mid in merchantIds)
            {
                var alerts = await _batchService.GetNearExpiryOrExpiredBatchesAsync(mid, daysThreshold);
                results.AddRange(alerts);
            }

            return Ok(results);
        }

        /// <summary>
        /// Look up batch by ID
        /// </summary>
        [HttpGet("{id}")]
        public async Task<ActionResult<ProductBatchDto>> GetById(int id)
        {
            var userId = User.GetUserId();
            if (!userId.HasValue) return Unauthorized();

            var batch = await _batchService.GetBatchByIdAsync(id);
            if (batch == null) return NotFound();

            var merchantIds = await _merchantService.GetMerchantIds(userId.Value);
            if (!merchantIds.Contains(batch.MerchantId))
                return Forbid();

            return Ok(batch);
        }

        /// <summary>
        /// Barcode lookup for handheld scanner
        /// </summary>
        [HttpGet("Barcode/{barcode}")]
        public async Task<ActionResult<ProductBatchDto>> GetByBarcode(string barcode)
        {
            var userId = User.GetUserId();
            var merchantIds = userId.HasValue ? await _merchantService.GetMerchantIds(userId.Value) : Array.Empty<int>();
            int? primaryMerchantId = merchantIds.FirstOrDefault();
            if (primaryMerchantId == 0) primaryMerchantId = null;

            var batch = await _batchService.GetBatchByBarcodeAsync(barcode, primaryMerchantId);
            if (batch == null) return NotFound($"No batch found with barcode '{barcode}'.");

            return Ok(batch);
        }

        /// <summary>
        /// Intake a new inventory batch into the warehouse
        /// </summary>
        [HttpPost]
        public async Task<ActionResult<ProductBatchDto>> Create([FromBody] CreateProductBatchDto dto)
        {
            if (dto == null) return BadRequest("Invalid batch payload.");

            var userId = User.GetUserId();
            if (!userId.HasValue) return Unauthorized();

            var merchantIds = await _merchantService.GetMerchantIds(userId.Value);
            if (dto.MerchantId <= 0)
            {
                dto.MerchantId = merchantIds.FirstOrDefault();
            }

            if (!merchantIds.Contains(dto.MerchantId))
            {
                return Forbid();
            }

            var userName = User.Identity?.Name ?? "WarehouseStaff";
            var created = await _batchService.CreateBatchAsync(dto, userName);

            return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
        }

        /// <summary>
        /// Adjust stock for damage, recount, or scrap
        /// </summary>
        [HttpPost("Adjust")]
        public async Task<ActionResult<ProductBatchDto>> AdjustStock([FromBody] StockAdjustmentDto dto)
        {
            if (dto == null) return BadRequest("Invalid adjustment payload.");

            var batch = await _batchService.GetBatchByIdAsync(dto.BatchId);
            if (batch == null) return NotFound();

            var userId = User.GetUserId();
            if (!userId.HasValue) return Unauthorized();

            var merchantIds = await _merchantService.GetMerchantIds(userId.Value);
            if (!merchantIds.Contains(batch.MerchantId))
            {
                return Forbid();
            }

            var userName = User.Identity?.Name ?? "WarehouseStaff";
            var updated = await _batchService.AdjustStockAsync(dto, userName);

            return Ok(updated);
        }
    }
}
