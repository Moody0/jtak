using System;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;
using OpenIddict.Validation.AspNetCore;
using App.ApiModels;
using App.Catalog.Data;
using App.Extensions;
using App.Shared.Entities.Enums;
using Modules.Catalog.Entities;
using Modules.Catalog.Services;
using Solf.Models;

namespace App.ApiControllers.V1.Warehouse
{
    [Route("api/v{version:apiVersion}/Warehouse/[controller]")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.MerchantPermission))]
    public class MerchantController : SolApiController
    {
        private readonly IMerchantService _merchantService;
        private readonly ICatalogUnitOfWork _uow;
        private readonly IMemoryCache _cache;
        private readonly ILogger<MerchantController> _logger;

        public MerchantController(
            IMerchantService merchantService,
            ICatalogUnitOfWork uow,
            IMemoryCache cache,
            ILogger<MerchantController> logger)
        {
            _merchantService = merchantService;
            _uow = uow;
            _cache = cache;
            _logger = logger;
        }

        /// <summary>
        /// Get the merchant profile for the logged in merchant owner
        /// </summary>
        [HttpGet]
        [Route("Profile")]
        public async Task<ActionResult<MerchantProfileDto>> GetProfile()
        {
            var uid = User.GetUserId();
            if (!uid.HasValue) return Unauthorized();

            var entity = await _merchantService.Queryable()
                .AsNoTracking()
                .FirstOrDefaultAsync(x => x.OwnerId == uid.Value);

            if (entity == null)
            {
                return NotFound("لم يتم العثور على متجر مرتبط بهذا الحساب");
            }

            return Ok(MapToProfileDto(entity));
        }

        /// <summary>
        /// Update the merchant profile details (Name, Bio, Tagline, Phone, Address, Logo, Cover)
        /// </summary>
        [HttpPut]
        [Route("Profile")]
        public async Task<ActionResult<MerchantProfileDto>> UpdateProfile([FromBody] MerchantProfileUpdateDto dto)
        {
            var uid = User.GetUserId();
            if (!uid.HasValue) return Unauthorized();

            var entity = await _merchantService.Queryable()
                .FirstOrDefaultAsync(x => x.OwnerId == uid.Value);

            if (entity == null)
            {
                return NotFound("لم يتم العثور على متجر مرتبط بهذا الحساب");
            }

            if (!string.IsNullOrWhiteSpace(dto.Title))
            {
                entity.Title = dto.Title.Trim();
            }

            if (dto.ShortDescription != null)
            {
                entity.ShortDescription = dto.ShortDescription.Trim();
            }

            if (dto.Description != null)
            {
                entity.Description = dto.Description.Trim();
            }

            if (dto.Phone1 != null)
            {
                entity.Phone1 = dto.Phone1.Trim();
            }

            if (dto.Phone2 != null)
            {
                entity.Phone2 = dto.Phone2.Trim();
            }

            if (dto.Address != null)
            {
                entity.Address = dto.Address.Trim();
            }

            if (dto.ShippingCoverageInMeters.HasValue && dto.ShippingCoverageInMeters.Value > 0)
            {
                entity.ShippingCoverageInMeters = dto.ShippingCoverageInMeters.Value;
            }

            if (dto.Lat.HasValue && dto.Lat.Value != 0)
            {
                entity.Lat = dto.Lat.Value;
            }

            if (dto.Lng.HasValue && dto.Lng.Value != 0)
            {
                entity.Lng = dto.Lng.Value;
            }

            // Parse existing photo parts to preserve either logo or cover if only one is updated
            string currentCover = "";
            string currentLogo = "";
            if (!string.IsNullOrWhiteSpace(entity.Photo))
            {
                var parts = entity.Photo.Split(',').Select(s => s.Trim()).Where(s => !string.IsNullOrEmpty(s)).ToArray();
                if (parts.Length > 0) currentCover = parts[0];
                if (parts.Length > 1) currentLogo = parts[1];
                else currentLogo = currentCover;
            }

            string newCover = dto.CoverBanner ?? currentCover;
            string newLogo = dto.Logo ?? currentLogo;

            if (string.IsNullOrEmpty(newCover) && !string.IsNullOrEmpty(newLogo))
            {
                newCover = newLogo;
            }
            else if (string.IsNullOrEmpty(newLogo) && !string.IsNullOrEmpty(newCover))
            {
                newLogo = newCover;
            }

            if (!string.IsNullOrEmpty(newCover) && !string.IsNullOrEmpty(newLogo))
            {
                entity.Photo = $"{newCover},{newLogo}";
            }

            await _uow.SaveChangesAsync();

            // Clear active caches for this merchant
            _cache.Remove($"ActiveMerchantPrices_{entity.Id}");
            _cache.Remove($"AllMerchantPrices_{entity.Id}");

            _logger.LogInformation("Merchant profile updated for MerchantId={0}, OwnerId={1}", entity.Id, uid.Value);

            return Ok(MapToProfileDto(entity));
        }

        /// <summary>
        /// Quick toggle for store availability status (Open/Closed)
        /// </summary>
        [HttpPut]
        [Route("ToggleStatus")]
        public async Task<ActionResult<bool>> ToggleStatus([FromBody] ToggleMerchantStatusRequest request)
        {
            var uid = User.GetUserId();
            if (!uid.HasValue) return Unauthorized();

            var entity = await _merchantService.Queryable()
                .OrderByDescending(x => x.Id)
                .FirstOrDefaultAsync(x => x.OwnerId == uid.Value);

            if (entity == null)
            {
                return NotFound("لم يتم العثور على متجر مرتبط بهذا الحساب");
            }

            entity.Active = request?.Active ?? !entity.Active;

            await _uow.SaveChangesAsync();

            _cache.Remove($"ActiveMerchantPrices_{entity.Id}");
            _cache.Remove($"AllMerchantPrices_{entity.Id}");

            _logger.LogInformation("Merchant active status toggled to {0} for MerchantId={1}", entity.Active, entity.Id);

            return Ok(entity.Active);
        }

        private static MerchantProfileDto MapToProfileDto(Merchant entity)
        {
            string cover = "";
            string logo = "";
            if (!string.IsNullOrWhiteSpace(entity.Photo))
            {
                var parts = entity.Photo.Split(',').Select(s => s.Trim()).Where(s => !string.IsNullOrEmpty(s)).ToArray();
                if (parts.Length >= 2)
                {
                    cover = parts[0];
                    logo = parts[1];
                }
                else if (parts.Length == 1)
                {
                    cover = parts[0];
                    logo = parts[0];
                }
            }

            return new MerchantProfileDto
            {
                Id = entity.Id,
                Title = entity.Title ?? "",
                ShortDescription = entity.ShortDescription ?? "",
                Description = entity.Description ?? "",
                Logo = logo,
                CoverBanner = cover,
                Phone1 = entity.Phone1 ?? "",
                Phone2 = entity.Phone2 ?? "",
                Address = entity.Address ?? "",
                ShippingCoverageInMeters = entity.ShippingCoverageInMeters,
                Lat = entity.Lat,
                Lng = entity.Lng,
                Active = entity.Active,
                MerchantKind = entity.MerchantKind
            };
        }
    }

    public class MerchantProfileDto
    {
        public int Id { get; set; }
        public string Title { get; set; }
        public string ShortDescription { get; set; }
        public string Description { get; set; }
        public string Logo { get; set; }
        public string CoverBanner { get; set; }
        public string Phone1 { get; set; }
        public string Phone2 { get; set; }
        public string Address { get; set; }
        public int ShippingCoverageInMeters { get; set; }
        public decimal Lat { get; set; }
        public decimal Lng { get; set; }
        public bool Active { get; set; }
        public MerchantKind MerchantKind { get; set; }
    }

    public class MerchantProfileUpdateDto
    {
        public string Title { get; set; }
        public string ShortDescription { get; set; }
        public string Description { get; set; }
        public string Logo { get; set; }
        public string CoverBanner { get; set; }
        public string Phone1 { get; set; }
        public string Phone2 { get; set; }
        public string Address { get; set; }
        public int? ShippingCoverageInMeters { get; set; }
        public decimal? Lat { get; set; }
        public decimal? Lng { get; set; }
    }

    public class ToggleMerchantStatusRequest
    {
        public bool? Active { get; set; }
    }
}
