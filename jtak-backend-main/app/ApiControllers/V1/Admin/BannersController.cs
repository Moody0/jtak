using App.Extensions;
using App.Shared.Services;
using AutoMapper;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using OpenIddict.Validation.AspNetCore;
using App.Shared.Entities;
using App.Shared.Entities.Domain;
using App.Shared.Data.App;
using Solf.Models;
using App.Shared.Entities.Enums;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.EntityFrameworkCore;
using System;
using System.Linq;
using System.Text.RegularExpressions;

namespace App.ApiControllers.V1.Admin
{
    [Route("api/v{version:apiVersion}/Admin/[controller]")]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.AdminPermission))]
    public class BannerController : SolApiController
    {
        private readonly IAppUnitOfWork _uow;
        private readonly INotificationService _notificationService;
        private readonly UserManager<AppUser> _userManager;
        private readonly IMapper _mapper;
        private readonly ILogger _logger;
        private readonly IBannerService _service;
        private readonly IMemoryCache _cache;
        private readonly IAdminAuditService _auditService;

        public BannerController(IAppUnitOfWork unitOfWork,
            INotificationService notificationService,
            UserManager<AppUser> userManager,
            IBannerService service,
            ILogger<BannerController> logger,
            IMemoryCache cache,
            IMapper mapper,
            IAdminAuditService auditService = null)
        {
            _uow = unitOfWork;
            _userManager = userManager;
            _notificationService = notificationService;
            _logger = logger;
            _mapper = mapper;
            _cache = cache;
            _service = service;
            _auditService = auditService;
        }


        /// <summary>
        /// Get a paged/filtered/ordered list of Banners
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Route("DataTable")]
        public async Task<ActionResult<TableResponseModel<BannerDto>>> DataTable([FromBody] MetronicTable request, [FromQuery] string section = "all", [FromQuery] string status = "all")
        {
            if (request != null && request.PageNumber > 0)
            {
                request.PageNumber -= 1;
            }
            return await _service.ListMetronicTableQueryable(request, x => new BannerDto
            {
                Id = x.Id,
                CreatedDate = x.CreatedDate,
                Title = x.Title,
                Description = x.Description,
                FeaturedImage = x.FeaturedImage,
                Order = x.Order,
                Url = x.Url,
                BannerLocation = x.BannerLocation,
                Active = x.Active
            }, x => (status == "all" || x.Active == (status == "active")) &&
                (section == "all" ||
                 (section == "daily" && (x.BannerLocation == BannerLocation.HomePage || x.BannerLocation == BannerLocation.All)) ||
                 (section == "dont_miss" && (x.BannerLocation == BannerLocation.DontMiss || x.BannerLocation == BannerLocation.All)) ||
                 (section == "both" && x.BannerLocation == BannerLocation.All)));
        }

        [HttpGet("Summary")]
        public async Task<ActionResult<object>> Summary()
        {
            var banners = _service.Queryable().AsNoTracking();
            return new { Total = await banners.CountAsync(), Active = await banners.CountAsync(x => x.Active),
                Daily = await banners.CountAsync(x => x.BannerLocation == BannerLocation.HomePage || x.BannerLocation == BannerLocation.All),
                DontMiss = await banners.CountAsync(x => x.BannerLocation == BannerLocation.DontMiss || x.BannerLocation == BannerLocation.All) };
        }

        public class BannerBulkRequest
        {
            public int[] Ids { get; set; }
            public bool Active { get; set; }
        }

        [HttpPost("BulkStatus")]
        public async Task<ActionResult<bool>> BulkStatus(BannerBulkRequest request)
        {
            if (request?.Ids == null || request.Ids.Length == 0 || request.Ids.Any(id => id <= 0))
                return BadRequest("اختر إعلانات صحيحة أولاً");
            var ids = request.Ids.Distinct().ToArray();
            var banners = await _service.Queryable().Where(x => ids.Contains(x.Id)).ToArrayAsync();
            if (banners.Length != ids.Length) return BadRequest("بعض الإعلانات لم تعد موجودة. أعد تحميل القائمة");
            if (request.Active && banners.Any(b => string.IsNullOrWhiteSpace(b.FeaturedImage)))
                return BadRequest("أضف صورة قبل تفعيل الإعلان");
            foreach (var banner in banners) banner.Active = request.Active;
            await _uow.SaveChangesAsync();
            InvalidateBannerCache();
            if (_auditService != null) await _auditService.LogAsync(new AdminAuditLogEntry {
                Module = "Banners", Action = "BulkStatus", EntityType = "Banner", EntityId = string.Join(",", ids),
                Description = request.Active ? "تفعيل الإعلانات المحددة" : "تعطيل الإعلانات المحددة", Result = "Success", AfterState = new { ids, request.Active } });
            return true;
        }

        [HttpPost("BulkDelete")]
        public async Task<ActionResult<bool>> BulkDelete(BannerBulkRequest request)
        {
            if (request?.Ids == null || request.Ids.Length == 0 || request.Ids.Any(id => id <= 0))
                return BadRequest("اختر إعلانات صحيحة أولاً");
            var ids = request.Ids.Distinct().ToArray();
            if (await _service.Queryable().CountAsync(x => ids.Contains(x.Id)) != ids.Length)
                return BadRequest("بعض الإعلانات لم تعد موجودة. أعد تحميل القائمة");
            foreach (var id in ids) await _service.DeleteAsync(id);
            await _uow.SaveChangesAsync();
            InvalidateBannerCache();
            if (_auditService != null) await _auditService.LogAsync(new AdminAuditLogEntry {
                Module = "Banners", Action = "BulkDelete", EntityType = "Banner", EntityId = string.Join(",", ids),
                Description = "حذف الإعلانات المحددة", Result = "Success" });
            return true;
        }


        /// <summary>
        /// Create Banner
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        public async Task<ActionResult<int>> Create(BannerDto model)
        {
            var error = Validate(model);
            if (error != null) return BadRequest(error);
            var uid = User.GetUserId();
            var entity = new Banner
            {
                Title = model.Title,
                Description = model.Description,
                FeaturedImage = model.FeaturedImage,
                Order = model.Order,
                Url = model.Url,
                BannerLocation = model.BannerLocation,
                Active = model.Active
            };
            _service.Insert(entity);
            await _uow.SaveChangesAsync();
            InvalidateBannerCache();

            if (_auditService != null)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Banners",
                    Action = "Create",
                    EntityType = "Banner",
                    EntityId = entity.Id.ToString(),
                    Description = $"إضافة إعلان جديد: {entity.Title}",
                    Result = "Success",
                    AfterState = new { entity.Id, entity.Title, entity.BannerLocation, entity.Active, entity.Order }
                });
            }

            return entity.Id;
        }

        /// <summary>
        /// Edit Banner
        /// </summary>
        /// <returns></returns>
        [HttpPut]
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        [Route("{id}")]
        public async Task<ActionResult<int>> Edit(int id, BannerDto model)
        {
            var error = Validate(model);
            if (error != null) return BadRequest(error);
            var entity = await _service.FindAsync(id);
            if (entity == null)
            {
                return BadRequest("Not found!");
            }

            var beforeState = new
            {
                entity.Id,
                entity.Title,
                entity.BannerLocation,
                entity.Active,
                entity.Order
            };

            var uid = User.GetUserId();
            entity.Title = model.Title;
            entity.Description = model.Description;
            entity.FeaturedImage = model.FeaturedImage;
            entity.Order = model.Order;
            entity.Url = model.Url;
            entity.BannerLocation = model.BannerLocation;
            entity.Active = model.Active;

            await _uow.SaveChangesAsync();
            InvalidateBannerCache();

            if (_auditService != null)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Banners",
                    Action = "Edit",
                    EntityType = "Banner",
                    EntityId = entity.Id.ToString(),
                    Description = $"تعديل الإعلان: {entity.Title}",
                    Result = "Success",
                    BeforeState = beforeState,
                    AfterState = new
                    {
                        entity.Id,
                        entity.Title,
                        entity.BannerLocation,
                        entity.Active,
                        entity.Order
                    }
                });
            }

            return entity.Id;
        }

        /// <summary>
        /// Delete Banner
        /// </summary>
        /// <returns></returns>
        [HttpDelete]
        [Route("{id}")]
        public async Task<ActionResult<bool>> Delete(int id)
        {
            var banner = await _service.FindAsync(id);
            if (banner == null) return NotFound("الإعلان غير موجود");
            await _service.DeleteAsync(id);
            await _uow.SaveChangesAsync();
            InvalidateBannerCache();

            if (_auditService != null)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Banners",
                    Action = "Delete",
                    EntityType = "Banner",
                    EntityId = id.ToString(),
                    Description = $"حذف الإعلان: {banner?.Title ?? id.ToString()}",
                    Result = "Success"
                });
            }

            return true;
        }

        private static string Validate(BannerDto model)
        {
            if (model == null || string.IsNullOrWhiteSpace(model.Title)) return "أدخل عنوان الإعلان";
            if (!Enum.IsDefined(typeof(BannerLocation), model.BannerLocation)) return "اختر مكان ظهور صحيحاً";
            if (model.Order < 0) return "ترتيب الإعلان لا يمكن أن يكون سالباً";
            if (model.Active && string.IsNullOrWhiteSpace(model.FeaturedImage)) return "أضف صورة قبل تفعيل الإعلان";
            model.Title = model.Title.Trim();
            model.Url = Regex.Replace(model.Url ?? "", @"#section:[a-z_]+", "", RegexOptions.IgnoreCase).Trim();
            var target = model.Url;
            if (target.Length == 0 || target == "none" || target == "no_link" || target == "offers" || target == "promotions") return null;
            if (Regex.IsMatch(target, @"^(restaurant|market|merchant|store|category):[1-9][0-9]*$") || Regex.IsMatch(target, @"^[1-9][0-9]*$")) return null;
            if (Uri.TryCreate(target, UriKind.Absolute, out var uri) && (uri.Scheme == "http" || uri.Scheme == "https") && !string.IsNullOrWhiteSpace(uri.Host)) return null;
            return "اختر وجهة صحيحة أو أدخل رابطاً يبدأ بـ https:// أو http://";
        }

        private void InvalidateBannerCache()
        {
            _cache.Remove($"BannerCache_{BannerLocation.HomePage}");
            _cache.Remove($"BannerCache_{BannerLocation.DontMiss}");
            _cache.Remove($"BannerCache_{BannerLocation.RestaurantsPage}");
            _cache.Remove($"BannerCache_{BannerLocation.MarketPage}");
            _cache.Remove($"BannerCache_{BannerLocation.All}");
            _cache.Remove("BannerCache_AllActive");
        }
    }
}
