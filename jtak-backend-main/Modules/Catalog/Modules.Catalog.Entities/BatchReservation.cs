using Solf.Base;
using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Modules.Catalog.Entities
{
    public class BatchReservation : AuditableEntity
    {
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int Id { get; set; }

        public int ProductBatchId { get; set; }
        public virtual ProductBatch ProductBatch { get; set; }

        public int OrderId { get; set; }

        public int OrderDetailId { get; set; }

        public int Quantity { get; set; }

        public bool IsDeducted { get; set; }

        public DateTime? DeductedDate { get; set; }

        public bool IsReleased { get; set; }

        public DateTime? ReleasedDate { get; set; }

        [StringLength(256)]
        public string ReleaseReason { get; set; }

        public bool IsPicked { get; set; }

        public DateTime? PickedDate { get; set; }

        [StringLength(128)]
        public string PickedBy { get; set; }
    }
}
