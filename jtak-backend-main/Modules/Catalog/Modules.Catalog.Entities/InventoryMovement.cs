using Solf.Base;
using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Modules.Catalog.Entities
{
    public enum InventoryMovementType
    {
        Reserve = 0,
        Release = 1,
        Deduction = 2,
        Return = 3,
        Damage = 4,
        Missing = 5,
        Adjustment = 6
    }

    public class InventoryMovement : AuditableEntity
    {
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int Id { get; set; }

        public int ProductBatchId { get; set; }
        public virtual ProductBatch ProductBatch { get; set; }

        public int ProductId { get; set; }

        public int MerchantId { get; set; }

        public int? OrderId { get; set; }

        public int? OrderDetailId { get; set; }

        public InventoryMovementType MovementType { get; set; }

        public int Quantity { get; set; }

        public int QuantityOnHandBefore { get; set; }

        public int QuantityOnHandAfter { get; set; }

        public int QuantityReservedBefore { get; set; }

        public int QuantityReservedAfter { get; set; }

        [StringLength(128)]
        public string BusinessKey { get; set; }

        [StringLength(512)]
        public string Reason { get; set; }

        [StringLength(128)]
        public string Reference { get; set; }
    }

    public class InventoryMovementDto
    {
        public int Id { get; set; }
        public int ProductBatchId { get; set; }
        public string BatchNumber { get; set; }
        public int ProductId { get; set; }
        public int MerchantId { get; set; }
        public int? OrderId { get; set; }
        public int? OrderDetailId { get; set; }
        public InventoryMovementType MovementType { get; set; }
        public string MovementTypeName => MovementType.ToString();
        public int Quantity { get; set; }
        public int QuantityOnHandBefore { get; set; }
        public int QuantityOnHandAfter { get; set; }
        public int QuantityReservedBefore { get; set; }
        public int QuantityReservedAfter { get; set; }
        public string BusinessKey { get; set; }
        public string Reason { get; set; }
        public string Reference { get; set; }
        public DateTime CreatedDate { get; set; }
        public string CreatedBy { get; set; }
    }
}
