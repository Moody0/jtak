using System.Globalization;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc.ModelBinding;

namespace App.Helpers
{
    // Mobile multipart requests use ASCII digits and a decimal point regardless
    // of Accept-Language. Form binding otherwise uses the request's culture.
    public sealed class InvariantMoneyFormBinder : IModelBinder
    {
        public Task BindModelAsync(ModelBindingContext context)
        {
            var value = context.ValueProvider.GetValue(context.ModelName);
            if (value == ValueProviderResult.None) return Task.CompletedTask;
            context.ModelState.SetModelValue(context.ModelName, value);
            const NumberStyles style = NumberStyles.AllowLeadingWhite | NumberStyles.AllowTrailingWhite |
                NumberStyles.AllowLeadingSign | NumberStyles.AllowDecimalPoint;
            if (decimal.TryParse(value.FirstValue, style, CultureInfo.InvariantCulture, out var amount))
                context.Result = ModelBindingResult.Success(amount);
            else
                context.ModelState.TryAddModelError(context.ModelName, "أدخل مبلغاً صحيحاً بالأرقام مع فاصلة عشرية نقطة عند الحاجة.");
            return Task.CompletedTask;
        }
    }
}
