using System.ComponentModel.DataAnnotations;
using App.Resources;

namespace App.Areas.Admin.Models
{
    public class SettingsVm
    {
        [Display(Name = "FooterNote", ResourceType = typeof(_Settings))]
        [UIHint("Multiline")]
        public string FooterNote { get; set; }
    }
}
