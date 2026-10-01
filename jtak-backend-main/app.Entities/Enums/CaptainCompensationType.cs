using System.ComponentModel.DataAnnotations;

namespace App.Shared.Entities.Enums
{
    /// <summary>
    /// Delivery Captain Compensation Model
    /// </summary>
    public enum CaptainCompensationType
    {
        /// <summary>
        /// 0: Salaried Employee (موظف براتب شهري) - earns 0 per order and remits 100% collected customer cash to company.
        /// </summary>
        [Display(Name = "موظف براتب")]
        SalariedEmployee = 0,

        /// <summary>
        /// 1: Per Kilometer (حسب الكيلومتر) - earns configured amount per km delivered (e.g. 25 SYP / km).
        /// </summary>
        [Display(Name = "حسب الكيلومتر")]
        PerKilometer = 1,

        /// <summary>
        /// 2: Percentage of Delivery Fee (نسبة من أجرة التوصيل) - earns configured % of original delivery fee (e.g. 60%).
        /// </summary>
        [Display(Name = "نسبة من أجرة التوصيل")]
        Percentage = 2
    }
}
