using System;
using System.ComponentModel.DataAnnotations;
using App.Shared.Entities.Resources;
using Solf.Base;
using URF.Core.EF.Trackable;

namespace App.Entities
{
    public class SyncTask : Entity, IAuditableEntity
    {
        [Key]
        public long Id { get; set; }
        
        [Display(Name = "IsSyncing", ResourceType = typeof(_SyncTask))]
        public bool IsSyncing { get; set; }
        [Display(Name = "SyncCompleteDate", ResourceType = typeof(_SyncTask))]
        public DateTime? SyncCompleteDate { get; set; }
        [Display(Name = "SyncedBytes", ResourceType = typeof(_SyncTask))]
        public long SyncedBytes { get; set; }
        [Display(Name = "SyncProcessNotes", ResourceType = typeof(_SyncTask))]
        public string SyncProcessNotes { get; set; }

        #region AuditableEntity
        [ScaffoldColumn(false)]
        public DateTime CreatedDate { get; set; }

        [MaxLength(256)]
        [ScaffoldColumn(false)]
        public string CreatedBy { get; set; }

        [ScaffoldColumn(false)]
        public DateTime UpdatedDate { get; set; }

        [MaxLength(256)]
        [ScaffoldColumn(false)]
        public string UpdatedBy { get; set; }

        [ScaffoldColumn(false)]
        public DateTime? DetetionDate { get; set; }

        [MaxLength(256)]
        [ScaffoldColumn(false)]
        public string DeletedBy { get; set; }
        #endregion
    }
}
