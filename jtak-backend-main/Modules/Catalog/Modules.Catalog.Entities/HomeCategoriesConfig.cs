using App.Shared.Entities.Enums;
using System.Collections.Generic;

namespace Modules.Catalog.Entities
{
    /// <summary>
    /// Where a home tile takes the customer. The destination is stored
    /// explicitly rather than guessed from the tile's title, so a category can
    /// be renamed, translated or added without any client needing to recognise
    /// the words in it.
    /// </summary>
    public enum HomeCategoryLinkType : byte
    {
        /// <summary>Marketplace, scoped to one product category.</summary>
        ProductCategory = 0,
        /// <summary>List of merchants of one kind, e.g. every restaurant.</summary>
        MerchantKind = 1,
        /// <summary>One specific store, opened directly.</summary>
        Merchant = 2,
        /// <summary>Search results for a fixed term.</summary>
        Search = 3
    }

    /// <summary>
    /// A single tile in the Home "shop by category" grid, entirely authored by
    /// the administrator.
    /// </summary>
    public class HomeCategoryTile
    {
        /// <summary>
        /// Stable identifier for the tile itself, independent of whatever it
        /// points at, so reordering and re-targeting never lose track of it.
        /// </summary>
        public string Id { get; set; }

        public string Title { get; set; }
        public string TitleEn { get; set; }

        /// <summary>
        /// Image shown on the tile. Falls back to the linked category's own
        /// icon when the administrator has not uploaded one.
        /// </summary>
        public string ImageUrl { get; set; }

        public int Order { get; set; }
        public bool Active { get; set; } = true;

        public HomeCategoryLinkType LinkType { get; set; }

        /// <summary>Target for <see cref="HomeCategoryLinkType.ProductCategory"/>.</summary>
        public int? ProductCategoryId { get; set; }

        /// <summary>Target for <see cref="HomeCategoryLinkType.MerchantKind"/>.</summary>
        public MerchantKind? MerchantKind { get; set; }

        /// <summary>Target for <see cref="HomeCategoryLinkType.Merchant"/>.</summary>
        public int? MerchantId { get; set; }

        /// <summary>Target for <see cref="HomeCategoryLinkType.Search"/>.</summary>
        public string SearchTerm { get; set; }
    }

    /// <summary>
    /// Persisted configuration of the Home categories section. Stored as a
    /// single JSON settings value under a language-neutral key, matching how
    /// the popular products section is configured.
    /// </summary>
    public class HomeCategoriesConfig
    {
        public const string SettingKey = "HomeCategoriesConfig";

        public bool Enabled { get; set; } = true;
        public string SectionTitle { get; set; } = "تسوق حسب الفئة";
        public string SectionTitleEn { get; set; } = "Shop by category";

        /// <summary>
        /// How many tiles the app shows. Zero means show every active tile.
        /// </summary>
        public int MaxItems { get; set; } = 8;

        public List<HomeCategoryTile> Tiles { get; set; } = new List<HomeCategoryTile>();
    }

    /// <summary>
    /// A tile as delivered to the app, with the destination already resolved
    /// and validated. The client routes purely on <see cref="LinkType"/>.
    /// </summary>
    public class HomeCategoryTileDto
    {
        public string Id { get; set; }
        public string Title { get; set; }
        public string TitleEn { get; set; }
        public string ImageUrl { get; set; }
        public int Order { get; set; }
        public HomeCategoryLinkType LinkType { get; set; }
        public int? ProductCategoryId { get; set; }
        public MerchantKind? MerchantKind { get; set; }
        public int? MerchantId { get; set; }
        public string SearchTerm { get; set; }

        /// <summary>
        /// Human readable description of the destination, so the dashboard can
        /// show what a tile actually opens without re-deriving it.
        /// </summary>
        public string TargetLabel { get; set; }

        /// <summary>
        /// False when the tile points at something that has since been deleted
        /// or deactivated. Such tiles are withheld from the app and flagged in
        /// the dashboard instead of silently opening the wrong screen.
        /// </summary>
        public bool TargetExists { get; set; } = true;
    }
}
