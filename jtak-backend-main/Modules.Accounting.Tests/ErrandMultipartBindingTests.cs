using System.Collections.Generic;
using System.IO;
using System.Globalization;
using System.Threading.Tasks;
using App.Helpers;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.ModelBinding;
using Microsoft.AspNetCore.Mvc.ModelBinding.Binders;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Primitives;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace Modules.Accounting.Tests
{
    public class ErrandMultipartBindingTests
    {
        [Theory]
        [InlineData("ar")]
        [InlineData("tr")]
        [InlineData("en")]
        public async Task ReceiptDtoBindsCostAndPhotoWithoutReceiptNumber(string language)
        {
            var services = new ServiceCollection();
            services.AddLogging();
            services.AddMvc();
            using var provider = services.BuildServiceProvider();
            var http = new DefaultHttpContext { RequestServices = provider };
            http.Request.ContentType = "multipart/form-data; boundary=test";
            var photo = new FormFile(new MemoryStream(new byte[] { 1, 2, 3 }), 0, 3, "ReceiptPhoto", "receipt.jpg");
            var files = new FormFileCollection { photo };
            var form = new FormCollection(new Dictionary<string, StringValues> {
                ["PurchaseCost"] = "30.00", ["ReceiptReference"] = ""
            }, files);
            http.Request.Form = form;
            var metadata = provider.GetRequiredService<IModelMetadataProvider>()
                .GetMetadataForType(typeof(App.ApiControllers.V1.Delivery.SubmitErrandReceiptDto));
            var binder = provider.GetRequiredService<IModelBinderFactory>().CreateBinder(
                new ModelBinderFactoryContext { Metadata = metadata, BindingInfo = new BindingInfo { BindingSource = BindingSource.Form }, CacheToken = metadata });
            var context = DefaultModelBindingContext.CreateBindingContext(new ActionContext { HttpContext = http },
                new CompositeValueProvider { new FormValueProvider(BindingSource.Form, form, CultureInfo.GetCultureInfo(language)),
                    new FormFileValueProvider(files) }, metadata, new BindingInfo { BindingSource = BindingSource.Form }, "");
            await binder.BindModelAsync(context);
            var dto = Assert.IsType<App.ApiControllers.V1.Delivery.SubmitErrandReceiptDto>(context.Result.Model);
            Assert.Equal(30m, dto.PurchaseCost);
            Assert.True(string.IsNullOrEmpty(dto.ReceiptReference));
            Assert.Equal(3, dto.ReceiptPhoto.Length);
            Assert.Equal(0, context.ModelState.ErrorCount);
        }

        private static ModelBindingContext Context(string value, string culture)
        {
            var action = new ActionContext { HttpContext = new DefaultHttpContext() };
            var form = new FormCollection(new Dictionary<string, StringValues> { ["PurchaseCost"] = value });
            return DefaultModelBindingContext.CreateBindingContext(action,
                new FormValueProvider(BindingSource.Form, form, CultureInfo.GetCultureInfo(culture)),
                new EmptyModelMetadataProvider().GetMetadataForType(typeof(decimal)), null, "PurchaseCost");
        }

        [Theory]
        [InlineData("ar", false)]
        [InlineData("tr-TR", true)]
        public async Task LegacyLocalizedFormBindingRejectsOrMisreadsTheMobileDecimalPoint(string language, bool misread)
        {
            var context = Context("30.00", language);
            await new DecimalModelBinder(NumberStyles.Float | NumberStyles.AllowThousands, NullLoggerFactory.Instance).BindModelAsync(context);
            if (misread) {
                Assert.Equal(3000m, context.Result.Model);
            } else {
                Assert.False(context.Result.IsModelSet);
                Assert.False(context.ModelState.IsValid);
            }
        }

        [Theory]
        [InlineData("ar", "30.00", "30")]
        [InlineData("ar-SY", "30.00", "30")]
        [InlineData("tr-TR", "30.00", "30")]
        [InlineData("fr-FR", "30.25", "30.25")]
        [InlineData("en-US", "30.00", "30")]
        public async Task MobileMultipartCostIsIndependentOfRequestLanguage(string culture, string value, string expected)
        {
            var context = Context(value, culture);
            await new InvariantMoneyFormBinder().BindModelAsync(context);
            Assert.True(context.Result.IsModelSet);
            Assert.Equal(0, context.ModelState.ErrorCount);
            Assert.Equal(decimal.Parse(expected, CultureInfo.InvariantCulture), context.Result.Model);
        }

        [Theory]
        [InlineData("30,00")]
        [InlineData("1,000")]
        [InlineData("abc")]
        public async Task AmbiguousOrInvalidWireAmountsAreRejected(string value)
        {
            var context = Context(value, "ar");
            await new InvariantMoneyFormBinder().BindModelAsync(context);
            Assert.False(context.Result.IsModelSet);
            Assert.False(context.ModelState.IsValid);
        }
    }
}
