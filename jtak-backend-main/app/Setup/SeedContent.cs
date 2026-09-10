using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using App.Shared.Services;
using App.Shared.Entities.Domain;
using Microsoft.AspNetCore.Hosting;
using App.Shared.Entities;
using Microsoft.AspNetCore.Identity;
using App.Helpers;
using Modules.Catalog.Entities;
using App.Catalog.Data;
using App.Orders.Data;
using App.Shared.Data.App;
using Modules.Catalog.Services;
using App.Shared.Entities.Enums;
using Microsoft.EntityFrameworkCore;
using OfficeOpenXml;
using System.IO;
using App.Shared.Services.Extentions;

namespace App.Setup
{
    public class SeedContent
    {
        private readonly Random R = new Random();
        private readonly IWebHostEnvironment env;
        private readonly IAppUnitOfWork aUOW;
        private readonly ICatalogUnitOfWork cUOW;
        private readonly IOrdersUnitOfWork oUOW;
        private readonly IFaqService _faqService;
        private readonly IProductCategoryService _catService;
        private readonly IProductService _productService;
        private readonly IMerchantService _merchantService;
        private readonly IGenericSettingService _genericSettingService;
        private readonly UserManager<AppUser> _userManager;
        private string Fid;
        private string GetFid()
        {
            if (Fid == null) Fid = env.SaveFile(env.WebRootPath + "\\images\\logo.jpg");
            return Fid;
        }

        public SeedContent(IAppUnitOfWork aUOW,
                           ICatalogUnitOfWork cUOW,
                           IOrdersUnitOfWork oUOW,
                           IWebHostEnvironment env,
                           IFaqService faqService,
                           IProductCategoryService catService,
                           IProductService productService,
                           IMerchantService merchantService,
                           IGenericSettingService genericSettingService,
                           UserManager<AppUser> userManager)
        {
            this.env = env;
            this.aUOW = aUOW;
            this.cUOW = cUOW;
            this.oUOW = oUOW;
            this._faqService = faqService;
            this._catService = catService;
            this._productService = productService;
            this._merchantService = merchantService;
            this._userManager = userManager;
            this._genericSettingService = genericSettingService;
        }
        public async Task SeedFaqs()
        {
            if (_faqService.Queryable().Any()) return;

            for (int i = 0; i < 10; i++)
            {
                _faqService.Insert(new Faq
                {
                    QuestionAr = $"السؤال {i}",
                    QuestionEn = $"Question {i}",
                    AnswerAr = $"الجواب {i}, الجواب {i} الجواب {i} الجواب {i}الجواب {i} الجواب {i} الجواب {i} الجواب {i}",
                    AnswerEn = $"Answer {i}, Answer {i} Answer {i} Answer {i} Answer {i} Answer {i} Answer {i} Answer {i}",
                });
            }
            await aUOW.SaveChangesAsync();
        }
        public async Task SeedCategories()
        {
            if (_catService.Queryable().Any()) return;

            ExcelPackage.LicenseContext = LicenseContext.NonCommercial;
            using var package = new ExcelPackage(new FileInfo(Path.Combine(env.ContentRootPath, "products.xlsx")));

            //Get a WorkSheet by index. Note that EPPlus indexes are base 1, not base 0!
            var cat1Sheet = package.Workbook.Worksheets[0];
            var cat2Sheet = package.Workbook.Worksheets[1];
            var start = cat1Sheet.Dimension.Start;
            var end = cat1Sheet.Dimension.End;

            var cat1Photos = new DirectoryInfo(Path.Combine(env.ContentRootPath, "cat1s")).GetFiles();

            // Added cat 1
            var cats1 = new List<ProductCategory>();
            for (int row = start.Row; row <= end.Row; row++)
            {
                string catName = cat1Sheet.Cells[row, 1].Text?.Trim();
                if (string.IsNullOrEmpty(catName?.Trim()))
                    continue;

                var catPhotoFile = cat1Photos.FirstOrDefault(x => x.Name.StartsWith($"{row}."))?.FullName;
                var photosDbId = catPhotoFile != null ? FileHelper.SaveFile(env, catPhotoFile) : null;

                cats1.Add(new ProductCategory { Title = catName, Active = true, ParentId = null, Icon = photosDbId, Order = row });
            }
            _catService.Insert(cats1);
            await cUOW.SaveChangesAsync();

            // Added cat 2
            var cats2 = new List<ProductCategory>();
            start = cat2Sheet.Dimension.Start;
            end = cat2Sheet.Dimension.End;
            for (int row = start.Row; row <= end.Row; row++)
            {
                string catName = cat2Sheet.Cells[row, 1].Text?.Trim();
                string pCatName = cat2Sheet.Cells[row, 2].Text?.Trim();
                var parentId = cats1.FirstOrDefault(c => c.Title == pCatName)?.Id;

                if (!parentId.HasValue || string.IsNullOrEmpty(catName?.Trim()))
                    continue;

                cats2.Add(new ProductCategory { Title = catName, Active = true, ParentId = parentId, Order = row });
            }
            _catService.Insert(cats2);
            await cUOW.SaveChangesAsync();
        }
        public async Task SeedMerchants()
        {
            if (_merchantService.Queryable().Any()) return;

            var vendor = (await _userManager.GetUsersInRoleAsync(nameof(AppRoleName.Merchant))).FirstOrDefault();

            var merchants = new[]{
                              new Merchant {  Title="Merchant01", Active=true, OwnerId = vendor.Id, Lat = RandomLat, Lng = RandomLng, ShippingCoverageInMeters = RandomShippingCoverage }};
            foreach (var merchant in merchants)
            {
                _merchantService.Insert(merchant);
            }
            await cUOW.SaveChangesAsync();
        }

        public async Task SeedProducts()
        {
            if (_productService.Queryable().Any()) return;
            ExcelPackage.LicenseContext = LicenseContext.NonCommercial;
            using var package = new ExcelPackage(new FileInfo(Path.Combine(env.ContentRootPath, "products.xlsx")));

            //Get a WorkSheet by index. Note that EPPlus indexes are base 1, not base 0!
            var sheet = package.Workbook.Worksheets[2];
            var start = sheet.Dimension.Start;
            var end = sheet.Dimension.End;

            // Added products
            var cats = await _catService.Queryable().Where(c => c.Active).ToListAsync();
            var productsPhotos = new DirectoryInfo(Path.Combine(env.ContentRootPath, "products")).GetFiles();
            var prods = new List<Product>();
            for (int row = start.Row; row <= end.Row; row++)
            {
                var prodName = sheet.Cells[row, 1].Text.Trim();
                var catName = sheet.Cells[row, 2].Text?.Trim();
                var unit = sheet.Cells[row, 3].Text.Trim();
                var catId = cats.FirstOrDefault(c => c.Title == catName)?.Id;
                if (!catId.HasValue || string.IsNullOrEmpty(prodName?.Trim()))
                    continue;

                var productPhotoFile = productsPhotos.FirstOrDefault(x => x.Name.StartsWith($"{row}."))?.FullName;
                var photosDbId = productPhotoFile != null ? FileHelper.SaveFile(env, productPhotoFile) : null;
                prods.Add(new Product { Title = prodName, Unit = unit, Currency = Currency.TRY, Active = true, ProductCategoryId = catId, Photos = photosDbId });
            }
            _productService.Insert(prods);
            await cUOW.SaveChangesAsync();
        }
        public async Task SeedMerchantProducts()
        {
            var products = await _productService.Queryable().ToArrayAsync();
            var merchants = await _merchantService.Queryable().ToArrayAsync();
            foreach (var merchant in merchants)
            {
                var mps = await _merchantService.GetAllMerchantPrices(merchant.Id);
                if (mps.Count > 0)
                    continue;

                var cost = R.Next(10, 100);
                var discount = (int)R.NextDouble() * cost;
                var newmps = products.Select(p => new MerchantProductAssignDto { ProductId = p.Id, MerchantPrice = cost, Discount = discount, AdditionalProfitPercent = R.Next(0, 5) }).ToArray();
                try
                {
                    await _merchantService.AssignMerchantProducts(new[] { merchant.Id }, newmps);
                }
                catch (Exception) { }
            }
        }

        public async Task SeedSettings()
        {
            if (_genericSettingService.Queryable().Any()) return;

            await _genericSettingService.SetValue("NextRaffel", DateTime.UtcNow.AddDays(30));
            await _genericSettingService.SetValue("TermsAndConditions_ar", "<p>الشروط والأحكام</p>");
            await _genericSettingService.SetValue("TermsAndConditions_en", "<p>Therms and Conditions</p>");
            await _genericSettingService.SetValue("TermsAndConditions_tr", "<p>Therms and Conditions</p>");
            await _genericSettingService.SetValue("About_ar", "<p>عن تطبيق منصة قل</p>");
            await _genericSettingService.SetValue("About_en", "<p>About SAY Platform</p>");
            await _genericSettingService.SetValue("About_tr", "<p>About SAY Platform</p>");
            await _genericSettingService.SetValue("PrivacyPolicy_ar", "<p>سياسة الخصوصية</p>");
            await _genericSettingService.SetValue("PrivacyPolicy_en", "<p>Privacy policy</p>");
            await _genericSettingService.SetValue("PrivacyPolicy_tr", "<p>Privacy policy</p>");
        }
        private string RandomPhone => $"0{R.Next(55000000, 56999999)}";
        private string RandomLocation => $"{25 + R.NextDouble()},{55 + R.NextDouble()}";
        //private IPuntal RandomPoint => PointExt.ToPoint(25 + R.NextDouble(), 55 + R.NextDouble());
        private double RandomRating => 5 * R.NextDouble();
        private async Task<string> RandomImages(int count)
        {
            var tasks = new List<Task<string>>();
            for (int i = 0; i < count; i++)
            {
                tasks.Add(env.SaveFileFromUrl($"https://placebeard.it/{1920}x{1080}.jpg"));
            }
            var results = await Task.WhenAll(tasks);
            return string.Join(",", results);
        }

        private string RandomImage => env.SaveFileFromUrl($"https://placebeard.it/{1920}x{1080}.jpg").GetAwaiter().GetResult();
        //private decimal RandomLat => 37.064258m + (decimal)R.NextDouble() / 40;
        //private decimal RandomLng => 37.378656m + (decimal)R.NextDouble() / 40;
        //private int RandomShippingCoverage => 2000 + (int)R.NextDouble() * 2000;
        private decimal RandomLat => 37.05637741088867m + (decimal)R.NextDouble() / 40;
        private decimal RandomLng => 37.33407211303711m + (decimal)R.NextDouble() / 40;
        private int RandomShippingCoverage => 5000 + (int)R.NextDouble() * 2000;
    }
}
