using App.Catalog.Data;
using App.Shared.Data.MultiContext;
using App.Shared.Entities.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Modules.Catalog.Entities;
using Modules.Catalog.Services;
using OpenIddict.Validation.AspNetCore;
using Solf.Base;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using URF.Core.Abstractions.Trackable;

namespace App.ApiControllers.V1.Admin
{
    /// <summary>
    /// Administration of the Home "shop by category" grid. The grid is entirely
    /// data driven: the administrator decides which tiles exist, their order,
    /// their wording and artwork, and crucially the screen each one opens.
    /// </summary>
    [Route("api/v{version:apiVersion}/Admin/[controller]")]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = App.Helpers.Authorization.DashboardAccessService.Policy)]
    public class HomeCategoriesController : SolApiController
    {
        private readonly IHomeCategoriesService _service;
        private readonly IProductCategoryService _categoryService;
        private readonly IMerchantService _merchantService;
        private readonly ITrackableRepository<MerchantProduct, CatalogDbContext> _merchantProductRepository;

        public HomeCategoriesController(IHomeCategoriesService service,
                                        IProductCategoryService categoryService,
                                        IMerchantService merchantService,
                                        ITrackableRepository<MerchantProduct, CatalogDbContext> merchantProductRepository)
        {
            _service = service;
            _categoryService = categoryService;
            _merchantService = merchantService;
            _merchantProductRepository = merchantProductRepository;
        }

        /// <summary>
        /// Current configuration together with every destination the
        /// administrator can choose from, so the dashboard never has to guess
        /// what is selectable.
        /// </summary>
        [HttpGet]
        public async Task<ActionResult<HomeCategoriesAdminVm>> Get()
        {
            var config = await _service.GetConfig();
            var visibleCategoryIds = await CatalogCategoryVisibility.GetIdsAsync(_categoryService.Queryable());

            var categories = await _categoryService.Queryable().AsNoTracking()
                                                   .Where(x => visibleCategoryIds.Contains(x.Id))
                                                   .OrderBy(x => x.ParentId == null ? 0 : 1)
                                                   .ThenBy(x => x.Title)
                                                   .Select(x => new HomeCategoryTargetDto
                                                   {
                                                       Id = x.Id,
                                                       Title = x.Title,
                                                       Icon = x.Icon,
                                                       ParentId = x.ParentId,
                                                       ParentTitle = x.Parent.Title
                                                   })
                                                   .ToArrayAsync();

            var merchants = await _merchantService.Queryable().AsNoTracking()
                                                  .Where(x => x.DeletionDate == null && x.Active)
                                                  .OrderBy(x => x.Title)
                                                  .Select(x => new HomeCategoryMerchantDto
                                                  {
                                                      Id = x.Id,
                                                      Title = x.Title,
                                                      Photo = x.Photo,
                                                      MerchantKind = x.MerchantKind
                                                  })
                                                  .ToArrayAsync();
            var jtakMarketId = await _merchantService.GetJtakMarketMerchantId();
            foreach (var merchant in merchants) merchant.IsJtakMarket = merchant.Id == jtakMarketId;

            // Match HomeCategoriesService: query offers directly so Pomelo does
            // not translate a correlated Product.SelectMany into CROSS APPLY.
            var availableOffers = await _merchantProductRepository.Queryable().AsNoTracking()
                .Where(mp => mp.Product.DeletionDate == null &&
                             mp.Product.Active &&
                             mp.Product.ProductCategoryId.HasValue &&
                             visibleCategoryIds.Contains(mp.Product.ProductCategoryId.Value) &&
                             mp.MerchantPrice > 0 &&
                             mp.Merchant.DeletionDate == null &&
                             mp.Merchant.Active)
                .Select(mp => new
                {
                    ProductId = mp.ProductId,
                    CategoryId = mp.Product.ProductCategoryId.Value,
                    mp.MerchantId
                })
                .ToArrayAsync();

            var categoryParents = categories.ToDictionary(x => x.Id, x => x.ParentId);
            foreach (var category in categories)
            {
                var categoryIds = GetCategoryTreeIds(category.Id, categoryParents);
                var matches = availableOffers
                    .Where(x => categoryIds.Contains(x.CategoryId))
                    .ToArray();
                category.ProductCount = matches.Select(x => x.ProductId).Distinct().Count();
                category.MerchantCount = matches.Select(x => x.MerchantId).Distinct().Count();
            }

            foreach (var merchant in merchants)
            {
                merchant.ProductCount = availableOffers
                    .Where(x => x.MerchantId == merchant.Id)
                    .Select(x => x.ProductId)
                    .Distinct()
                    .Count();
            }

            var merchantKindCounts = merchants
                .GroupBy(x => x.MerchantKind)
                .ToDictionary(x => x.Key, x => x.Count());

            var merchantCategoryMap = availableOffers
                .GroupBy(x => x.MerchantId)
                .ToDictionary(
                    g => g.Key,
                    g => g.SelectMany(x => GetCategoryAncestorIds(x.CategoryId, categoryParents))
                          .Distinct()
                          .OrderBy(id => id)
                          .ToArray()
                );

            return new HomeCategoriesAdminVm
            {
                Config = config,
                Tiles = await _service.GetTiles(activeOnly: false),
                AvailableCategories = categories,
                AvailableMerchants = merchants,
                AvailableMerchantKinds = Enum.GetValues(typeof(MerchantKind))
                                             .Cast<MerchantKind>()
                                             .Select(x => new HomeCategoryMerchantKindDto
                                             {
                                                 Value = (int)x,
                                                 Name = x.ToString(),
                                                 MerchantCount = merchantKindCounts.TryGetValue(x, out var count)
                                                     ? count
                                                     : 0
                                             })
                                             .ToArray(),
                MerchantCategoryMap = merchantCategoryMap
            };
        }

        /// <summary>
        /// Replaces the whole configuration. The grid is short and is always
        /// edited as one arrangement, so saving it wholesale avoids the partial
        /// update races a per-tile API would introduce.
        /// </summary>
        [HttpPut]
        public async Task<ActionResult<HomeCategoryTileDto[]>> Put(HomeCategoriesConfig config)
        {
            if (config == null)
                return BadRequest("لا توجد إعدادات للحفظ");
            if (config.MaxItems < 0) return BadRequest("عدد الفئات لا يمكن أن يكون سالباً");
            // Older dashboard clients do not send this section; preserve its saved configuration.
            config.OtherStores ??= (await _service.GetConfig()).OtherStores ?? new OtherStoresSectionConfig();
            var otherStores = config.OtherStores;
            if (string.IsNullOrWhiteSpace(otherStores.Title) || otherStores.Title.Length > 120 ||
                (otherStores.TitleEn?.Length ?? 0) > 120)
                return BadRequest("أدخل عنوان قسم المتاجر الأخرى، بحد أقصى 120 حرفاً.");
            otherStores.MerchantIds ??= new List<int>();
            if (otherStores.MerchantIds.Count > 100 || otherStores.MerchantIds.Any(id => id <= 0) ||
                otherStores.MerchantIds.Distinct().Count() != otherStores.MerchantIds.Count)
                return BadRequest("اختر حتى 100 متجر دون تكرار في قسم المتاجر الأخرى.");
            if (!otherStores.Automatic && otherStores.MerchantIds.Any())
            {
                var merchantIds = otherStores.MerchantIds.ToArray();
                var existingCount = await _merchantService.Queryable().AsNoTracking()
                    .CountAsync(x => merchantIds.Contains(x.Id) && x.DeletionDate == null);
                if (existingCount != merchantIds.Length)
                    return BadRequest("بعض المتاجر المحددة حُذفت. أزلها من القسم ثم أعد الحفظ.");
            }
            var ids = (config.Tiles ?? new List<HomeCategoryTile>()).Where(t => t != null && !string.IsNullOrWhiteSpace(t.Id)).Select(t => t.Id).ToArray();
            if (ids.Distinct().Count() != ids.Length) return BadRequest("لا يمكن تكرار معرف الفئة");

            foreach (var tile in config.Tiles ?? new List<HomeCategoryTile>())
            {
                var error = Validate(tile);
                if (error != null)
                    return BadRequest(error);
            }

            if ((config.Tiles ?? new List<HomeCategoryTile>())
                .Count(tile => tile.LinkType == HomeCategoryLinkType.ErrandRequests) > 1)
            {
                return BadRequest("يمكن إضافة فئة «طلبات» مرة واحدة فقط.");
            }

            await _service.SaveConfig(config);
            return await _service.GetTiles(activeOnly: false);
        }

        /// <summary>
        /// A tile that points nowhere would render in the app and then fail on
        /// tap, so an incomplete destination is rejected at save time.
        /// </summary>
        private static string Validate(HomeCategoryTile tile)
        {
            if (tile == null) return "بيانات الفئة غير مكتملة";
            if (!Enum.IsDefined(typeof(HomeCategoryLinkType), tile.LinkType)) return "نوع وجهة غير معروف";
            if (tile.MerchantKind.HasValue && !Enum.IsDefined(typeof(MerchantKind), tile.MerchantKind.Value)) return "نوع متجر غير معروف";
            if (tile.ProductCategoryId <= 0 || tile.SecondaryProductCategoryId <= 0 || tile.MerchantId <= 0 || tile.RestaurantCategoryId <= 0) return "اختر وجهة صحيحة للفئة";
            if (string.IsNullOrWhiteSpace(tile.Title))
                return "كل فئة يجب أن تحتوي على اسم";

            if (tile.RestaurantCategoryId.HasValue &&
                (tile.LinkType != HomeCategoryLinkType.MerchantKind ||
                 tile.MerchantKind != MerchantKind.Restaurant))
            {
                return $"الفئة \"{tile.Title}\" يمكنها اختيار فلتر مطاعم فقط عند فتح قائمة المطاعم";
            }

            switch (tile.LinkType)
            {
                case HomeCategoryLinkType.ProductCategory when !tile.ProductCategoryId.HasValue:
                    return $"الفئة \"{tile.Title}\" يجب أن ترتبط بقسم من الأقسام";
                case HomeCategoryLinkType.Merchant when !tile.MerchantId.HasValue:
                    return $"الفئة \"{tile.Title}\" يجب أن ترتبط بمتجر";
                case HomeCategoryLinkType.MerchantKind when !tile.MerchantKind.HasValue:
                    return $"الفئة \"{tile.Title}\" يجب أن ترتبط بنوع متاجر";
                case HomeCategoryLinkType.Search when string.IsNullOrWhiteSpace(tile.SearchTerm):
                    return $"الفئة \"{tile.Title}\" يجب أن تحتوي على كلمة بحث";
                case HomeCategoryLinkType.MerchantCategory when !tile.MerchantId.HasValue || !tile.ProductCategoryId.HasValue:
                    return $"الفئة \"{tile.Title}\" يجب أن ترتبط بمتجر وقسم محددين";
                case HomeCategoryLinkType.ErrandRequests:
                    return null;
                default:
                    return null;
            }
        }

        private static HashSet<int> GetCategoryTreeIds(
            int rootId,
            IReadOnlyDictionary<int, int?> parentByCategoryId)
        {
            var result = new HashSet<int> { rootId };
            var added = true;
            while (added)
            {
                added = false;
                foreach (var category in parentByCategoryId)
                {
                    if (category.Value.HasValue &&
                        result.Contains(category.Value.Value) &&
                        result.Add(category.Key))
                    {
                        added = true;
                    }
                }
            }

            return result;
        }

        private static HashSet<int> GetCategoryAncestorIds(
            int categoryId,
            IReadOnlyDictionary<int, int?> parentByCategoryId)
        {
            var result = new HashSet<int> { categoryId };
            var currentId = categoryId;
            while (parentByCategoryId.TryGetValue(currentId, out var parentId) &&
                   parentId.HasValue && result.Add(parentId.Value))
            {
                currentId = parentId.Value;
            }

            return result;
        }
    }

    public class HomeCategoriesAdminVm
    {
        public HomeCategoriesConfig Config { get; set; }
        public HomeCategoryTileDto[] Tiles { get; set; }
        public HomeCategoryTargetDto[] AvailableCategories { get; set; }
        public HomeCategoryMerchantDto[] AvailableMerchants { get; set; }
        public HomeCategoryMerchantKindDto[] AvailableMerchantKinds { get; set; }
        public Dictionary<int, int[]> MerchantCategoryMap { get; set; } = new Dictionary<int, int[]>();
    }

    public class HomeCategoryTargetDto
    {
        public int Id { get; set; }
        public string Title { get; set; }
        public string Icon { get; set; }
        public int? ParentId { get; set; }
        public string ParentTitle { get; set; }
        public int ProductCount { get; set; }
        public int MerchantCount { get; set; }
    }

    public class HomeCategoryMerchantDto
    {
        public bool IsJtakMarket { get; set; }
        public int Id { get; set; }
        public string Title { get; set; }
        public string Photo { get; set; }
        public MerchantKind MerchantKind { get; set; }
        public int ProductCount { get; set; }
    }

    public class HomeCategoryMerchantKindDto
    {
        public int Value { get; set; }
        public string Name { get; set; }
        public int MerchantCount { get; set; }
    }
}
