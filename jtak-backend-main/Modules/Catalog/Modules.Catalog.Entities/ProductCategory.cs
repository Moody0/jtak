using Solf.Base;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Modules.Catalog.Entities
{
    public class ProductCategory : SoftDeleteEntity
    {
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int Id { get; set; }

        //[Required]
        [StringLength(128)]
        public string Title { get; set; }
        public string Icon { get; set; }
        public bool Active { get; set; } = true;

        public int? ParentId { get; set; }
        public ProductCategory Parent { get; set; }
        public int Order { get; set; }

        public string SubCategoriesCsv { get; set; }

        [InverseProperty("Parent")]
        public virtual ICollection<ProductCategory> SubCategories { get; set; }
        public virtual ICollection<Product> Products { get; set; }
    }

    public class ProductCategoryDto
    {
        public int Id { get; set; }
        public string Title { get; set; }
        public string Icon { get; set; }
        public int? ParentId { get; set; }
        public string Parent { get; set; }
        public bool Active { get; set; }
        public int Order { get; set; }
        public ProductCategoryDto[] SubCategories { get; set; }
    }
}
