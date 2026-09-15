using App.Shared.Entities.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Modules.Catalog.Entities;
using Modules.Catalog.Services;
using OpenIddict.Validation.AspNetCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace App.ApiControllers.V1.Admin
{
    /// <summary>
    /// Administration of the Home "shop by category" grid. The grid is entirely
    /// data driven: the administrator decides which tiles exist, their order,
    /// their wording and artwork, and crucially the screen each one opens.
    /// </summary>
    [Route("api/v{version:apiVersion}/Admin/[controller]")]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.AdminPermission))]
    public class HomeCategoriesController : SolApiController
    {
        private readonly IHomeCategoriesService _service;
        private readonly IProductCategoryService _categoryService;
        private readonly IMerchantService _merchantService;

        public HomeCategoriesController(IHomeCategoriesService service,
                                        IProductCategoryService categoryService,
                                        IMerchantService merchantService)
        {
            _service = service;
            _categoryService = categoryService;
            _merchantService = merchantService;
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

            var categories = await _categoryService.Queryable().AsNoTracking()
                                                   .Where(x => x.DeletionDate == null && x.Active)
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
                                                 Name = x.ToString()
                                             })
                                             .ToArray()
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

            foreach (var tile in config.Tiles ?? new List<HomeCategoryTile>())
            {
                var error = Validate(tile);
                if (error != null)
                    return BadRequest(error);
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
            if (string.IsNullOrWhiteSpace(tile.Title))
                return "كل فئة يجب أن تحتوي على اسم";

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
                default:
                    return null;
            }
        }
    }

    public class HomeCategoriesAdminVm
    {
        public HomeCategoriesConfig Config { get; set; }
        public HomeCategoryTileDto[] Tiles { get; set; }
        public HomeCategoryTargetDto[] AvailableCategories { get; set; }
        public HomeCategoryMerchantDto[] AvailableMerchants { get; set; }
        public HomeCategoryMerchantKindDto[] AvailableMerchantKinds { get; set; }
    }

    public class HomeCategoryTargetDto
    {
        public int Id { get; set; }
        public string Title { get; set; }
        public string Icon { get; set; }
        public int? ParentId { get; set; }
        public string ParentTitle { get; set; }
    }

    public class HomeCategoryMerchantDto
    {
        public int Id { get; set; }
        public string Title { get; set; }
        public string Photo { get; set; }
        public MerchantKind MerchantKind { get; set; }
    }

    public class HomeCategoryMerchantKindDto
    {
        public int Value { get; set; }
        public string Name { get; set; }
    }
}
