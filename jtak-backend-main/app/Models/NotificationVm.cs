using System;
using System.ComponentModel.DataAnnotations;
using App.Shared.Entities.Resources;
using App.Resources;

namespace App.Models
{
    public class NotificationVm
    {
        [Display(Name = "Id", ResourceType = typeof(_Entities))]
        public int Id { get; set; }
        [Display(Name = "Title", ResourceType = typeof(_Notifications))]
        public string Title { get; set; }
        [Display(Name = "Text", ResourceType = typeof(_Notifications))]
        public string Text { get; set; }
        [Display(Name = "ViewDate", ResourceType = typeof(_Notifications))]
        public DateTime? ViewDate { get; set; }
        [Display(Name = "Topic", ResourceType = typeof(_Notifications))]
        public string Topic { get; set; }
        [Display(Name = "CreatedDate", ResourceType = typeof(_Entities))]
        public DateTime CreatedDate { get; set; }
    }
}
