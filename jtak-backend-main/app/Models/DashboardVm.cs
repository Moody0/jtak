using App.Shared.Entities.Resources;
using System.ComponentModel.DataAnnotations;

namespace App.Models
{
    public class DashboardVm
    {
        [Display(Name = "UsersCount", ResourceType = typeof(_Content))]
        public int UsersCount { get; set; }
        [Display(Name = "CoursesCount", ResourceType = typeof(_Content))]
        public int CoursesCount { get; set; }
        [Display(Name = "LessonsCount", ResourceType = typeof(_Content))]
        public int LessonsCount { get; set; }
        [Display(Name = "QuestionsCount", ResourceType = typeof(_Content))]
        public int QuestionsCount { get; set; }

    }
}
