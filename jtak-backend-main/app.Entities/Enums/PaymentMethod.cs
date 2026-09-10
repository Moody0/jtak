using App.Shared.Entities.Resources;
using System.ComponentModel.DataAnnotations;

namespace App.Shared.Entities.Enums
{
    //[JsonConverter(typeof(JsonStringEnumConverter))]
    public enum PaymentMethod
    {
        [Display(Name = "PayOnDelivery", ResourceType = typeof(_PaymentMethod))]
        PayOnDelivery = 0,
        [Display(Name = "CreditCardPayment", ResourceType = typeof(_PaymentMethod))]
        CreditCardPayment = 1
    }
}
