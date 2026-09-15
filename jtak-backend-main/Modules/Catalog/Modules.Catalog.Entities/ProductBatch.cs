using Solf.Base;
using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Modules.Catalog.Entities
{
    public class ProductBatch : SoftDeleteEntity
    {
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int Id { get; set; }

        public int ProductId { get; set; }
        public virtual Product Product { get; set; }

        public int MerchantId { get; set; }
        public virtual Merchant Merchant { get; set; }

        [Required]
        [StringLength(64)]
        public string BatchNumber { get; set; }

        [StringLength(64)]
        public string LotNumber { get; set; }

        [Required]
        [StringLength(64)]
        public string Barcode { get; set; }

        [StringLength(64)]
        public string Sku { get; set; }

        /// <summary>
        /// Dark Store physical location (e.g. Aisle-3, Rack-B, Bin-12)
        /// </summary>
        [StringLength(128)]
        public string LocationBin { get; set; }

        public DateTime? ManufactureDate { get; set; }

        [Required]
        public DateTime ExpirationDate { get; set; }

        /// <summary>
        /// Physical units on shelf
        /// </summary>
        public int QuantityOnHand { get; set; }

        /// <summary>
        /// Units reserved for orders being picked
        /// </summary>
        public int QuantityReserved { get; set; }

        [NotMapped]
        public int QuantityAvailable => Math.Max(0, QuantityOnHand - QuantityReserved);

        [Column(TypeName = "decimal(18,2)")]
        public decimal CostPrice { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal? SellingPrice { get; set; }

        public BatchStatus Status { get; set; } = BatchStatus.Active;

        [StringLength(500)]
        public string Notes { get; set; }
    }
}
