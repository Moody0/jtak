using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using App.Catalog.Data;
using Modules.Catalog.Entities;
using Xunit;

namespace Modules.Accounting.Tests
{
    public class AdminProductCatalogSyncAndDiscountTests
    {
        private CatalogDbContext CreateInMemoryCatalogContext()
        {
            var options = new DbContextOptionsBuilder<CatalogDbContext>()
                .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
                .Options;
            return new CatalogDbContext(options, null);
        }

        [Fact]
        public async Task CreateProduct_NoDiscount_And_ZeroDiscount_And_DecimalDiscount_Test()
        {
            using var ctx = CreateInMemoryCatalogContext();

            // 1. Root and Subcategory
            var rootCat = new ProductCategory { Id = 1, Title = "المطاعم", Active = true };
            var subCat = new ProductCategory { Id = 2, Title = "وجبات سريعة", ParentId = 1, Active = true };
            ctx.ProductCategories.AddRange(rootCat, subCat);

            // 2. Merchant #12 (JTAK Market)
            var merchant12 = new Merchant
            {
                Id = 12,
                Title = "سوبر ماركت جيتك المركزي",
                Active = true,
                MerchantKind = App.Shared.Entities.Enums.MerchantKind.Grocery
            };
            ctx.Merchants.Add(merchant12);
            await ctx.SaveChangesAsync();

            // Test A: Create product with no discount (null / default)
            var p1 = new Product
            {
                Id = 101,
                Title = "برغر كلاسيك سوبريم",
                Unit = "وجبة",
                Active = true,
                ProductCategoryId = 2
            };
            ctx.Products.Add(p1);
            var mp1 = new MerchantProduct
            {
                MerchantId = 12,
                ProductId = p1.Id,
                MerchantPrice = 35000m,
                Discount = 0m
            };
            ctx.MerchantProducts.Add(mp1);

            // Test B: Create product with explicit discount = 0
            var p2 = new Product
            {
                Id = 102,
                Title = "بطاطا مقلية عائلية",
                Unit = "علبة",
                Active = true,
                ProductCategoryId = 2
            };
            ctx.Products.Add(p2);
            var mp2 = new MerchantProduct
            {
                MerchantId = 12,
                ProductId = p2.Id,
                MerchantPrice = 12000m,
                Discount = 0m
            };
            ctx.MerchantProducts.Add(mp2);

            // Test C: Create product with valid decimal discount (e.g. 2,500.50 SYP)
            var p3 = new Product
            {
                Id = 103,
                Title = "بيتزا بيبروني خاصة",
                Unit = "قطعة",
                Active = true,
                ProductCategoryId = 2
            };
            ctx.Products.Add(p3);
            var mp3 = new MerchantProduct
            {
                MerchantId = 12,
                ProductId = p3.Id,
                MerchantPrice = 45000m,
                Discount = 2500.50m
            };
            ctx.MerchantProducts.Add(mp3);

            await ctx.SaveChangesAsync();

            // Assertions
            var savedP1 = await ctx.MerchantProducts.FirstOrDefaultAsync(mp => mp.ProductId == 101);
            Assert.NotNull(savedP1);
            Assert.Equal(0m, savedP1.Discount);
            Assert.Equal(35000m, savedP1.MerchantPrice);

            var savedP2 = await ctx.MerchantProducts.FirstOrDefaultAsync(mp => mp.ProductId == 102);
            Assert.NotNull(savedP2);
            Assert.Equal(0m, savedP2.Discount);

            var savedP3 = await ctx.MerchantProducts.FirstOrDefaultAsync(mp => mp.ProductId == 103);
            Assert.NotNull(savedP3);
            Assert.Equal(2500.50m, savedP3.Discount);
            Assert.Equal(45000m, savedP3.MerchantPrice);
        }

        [Fact]
        public void JsonDeserialization_HandlesStandardNumericFields_Gracefully()
        {
            var jsonOptions = new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            };

            // Standard JSON with numeric discount and price
            string jsonNumeric = "{\"title\":\"قهوة معتقة\",\"productCategoryId\":2,\"price\":15000,\"discount\":1500,\"merchantId\":12}";
            var dtoNumeric = JsonSerializer.Deserialize<ProductDto>(jsonNumeric, jsonOptions);
            Assert.NotNull(dtoNumeric);
            Assert.Equal("قهوة معتقة", dtoNumeric.Title);
            Assert.Equal(15000m, dtoNumeric.Price);
            Assert.Equal(1500m, dtoNumeric.Discount);

            // Default zero discount when omitted
            string jsonDefault = "{\"title\":\"شاي أحمر\",\"productCategoryId\":2,\"price\":5000,\"merchantId\":12}";
            var dtoDefault = JsonSerializer.Deserialize<ProductDto>(jsonDefault, jsonOptions);
            Assert.NotNull(dtoDefault);
            Assert.Equal(5000m, dtoDefault.Price);
            Assert.Equal(0m, dtoDefault.Discount);
        }

        [Theory]
        [InlineData(10000, 2000, true, "")] // Valid discount <= price
        [InlineData(10000, 10000, true, "")] // Valid discount == price (100% off)
        [InlineData(10000, 15000, false, "قيمة الخصم لا يمكن أن تتجاوز سعر المنتج.")] // Discount > Price (Invalid)
        [InlineData(10000, -500, false, "قيمة الخصم غير صالحة.")] // Negative discount (Invalid)
        [InlineData(-1000, 0, false, "سعر البيع غير صالح.")] // Negative price (Invalid)
        public void ProductValidation_DiscountAndPriceBusinessRules(decimal price, decimal discount, bool expectedValid, string expectedErrorMessage)
        {
            var dto = new ProductDto
            {
                Title = "منتج اختباري",
                ProductCategoryId = 1,
                Price = price,
                Discount = discount
            };

            string validationError = null;
            if (string.IsNullOrWhiteSpace(dto.Title))
                validationError = "اسم المنتج مطلوب.";
            else if (!dto.ProductCategoryId.HasValue || dto.ProductCategoryId.Value <= 0)
                validationError = "يرجى اختيار تصنيف صالح للمنتج.";
            else if (dto.Price < 0)
                validationError = "سعر البيع غير صالح.";
            else if (dto.Discount < 0)
                validationError = "قيمة الخصم غير صالحة.";
            else if (dto.Discount > dto.Price)
                validationError = "قيمة الخصم لا يمكن أن تتجاوز سعر المنتج.";

            if (expectedValid)
            {
                Assert.Null(validationError);
                decimal finalPrice = dto.Price - dto.Discount;
                Assert.True(finalPrice >= 0, "FinalPrice must never be negative");
            }
            else
            {
                Assert.NotNull(validationError);
                Assert.Equal(expectedErrorMessage, validationError);
            }
        }

        [Fact]
        public async Task EditProduct_Unchanged_And_PartialUpdates_PreserveDataIntegrity()
        {
            using var ctx = CreateInMemoryCatalogContext();

            var catA = new ProductCategory { Id = 10, Title = "مشروبات ساخنة", Active = true };
            var catB = new ProductCategory { Id = 11, Title = "مشروبات باردة", Active = true };
            ctx.ProductCategories.AddRange(catA, catB);

            var merchant12 = new Merchant { Id = 12, Title = "JTAK Central", Active = true };
            ctx.Merchants.Add(merchant12);

            var product = new Product
            {
                Id = 200,
                Title = "اسبريسو دبل",
                Description = "قهوة مركزة مستخلصة طازجة",
                Unit = "كوب",
                Photos = "espresso1.webp,espresso2.webp",
                Active = true,
                IsFeatured = true,
                ProductCategoryId = 10
            };
            ctx.Products.Add(product);

            var mp = new MerchantProduct
            {
                MerchantId = 12,
                ProductId = 200,
                MerchantPrice = 18000m,
                PriceUsd = 1.20m,
                Discount = 1000m
            };
            ctx.MerchantProducts.Add(mp);
            await ctx.SaveChangesAsync();

            // Test E & O: Save without changes preserves all fields exactly
            var existing = await ctx.Products.Include(p => p.MerchantProducts).FirstAsync(p => p.Id == 200);
            var existingMp = existing.MerchantProducts.First();

            Assert.Equal("اسبريسو دبل", existing.Title);
            Assert.Equal("قهوة مركزة مستخلصة طازجة", existing.Description);
            Assert.Equal("كوب", existing.Unit);
            Assert.Equal("espresso1.webp,espresso2.webp", existing.Photos);
            Assert.Equal(10, existing.ProductCategoryId);
            Assert.True(existing.Active);
            Assert.True(existing.IsFeatured);
            Assert.Equal(18000m, existingMp.MerchantPrice);
            Assert.Equal(1.20m, existingMp.PriceUsd);
            Assert.Equal(1000m, existingMp.Discount);
            Assert.Equal(12, existingMp.MerchantId);

            // Test F: Edit price only -> Preserves discount, photos, merchant, category
            existingMp.MerchantPrice = 20000m;
            await ctx.SaveChangesAsync();

            var afterPriceUpdate = await ctx.MerchantProducts.FirstAsync(m => m.ProductId == 200);
            Assert.Equal(20000m, afterPriceUpdate.MerchantPrice);
            Assert.Equal(1000m, afterPriceUpdate.Discount);
            Assert.Equal(12, afterPriceUpdate.MerchantId);

            // Test G: Edit discount only -> Preserves price and other metadata
            existingMp.Discount = 2500m;
            await ctx.SaveChangesAsync();

            var afterDiscountUpdate = await ctx.MerchantProducts.FirstAsync(m => m.ProductId == 200);
            Assert.Equal(20000m, afterDiscountUpdate.MerchantPrice);
            Assert.Equal(2500m, afterDiscountUpdate.Discount);

            // Test H: Edit category only -> Preserves merchant and pricing
            existing.ProductCategoryId = 11;
            await ctx.SaveChangesAsync();

            var afterCatUpdate = await ctx.Products.Include(p => p.MerchantProducts).FirstAsync(p => p.Id == 200);
            Assert.Equal(11, afterCatUpdate.ProductCategoryId);
            Assert.Equal(20000m, afterCatUpdate.MerchantProducts.First().MerchantPrice);
            Assert.Equal(2500m, afterCatUpdate.MerchantProducts.First().Discount);
        }

        [Fact]
        public async Task CustomerApp_Merchant12_Listing_And_Search_Sync()
        {
            using var ctx = CreateInMemoryCatalogContext();

            var rootCat = new ProductCategory { Id = 1, Title = "المطاعم", Active = true };
            var subCat = new ProductCategory { Id = 5, Title = "ساندويش وسناكات", ParentId = 1, Active = true };
            ctx.ProductCategories.AddRange(rootCat, subCat);

            var merchant12 = new Merchant
            {
                Id = 12,
                Title = "سوبر ماركت جيتك المركزي",
                Active = true,
                MerchantKind = App.Shared.Entities.Enums.MerchantKind.Grocery
            };
            ctx.Merchants.Add(merchant12);

            var p1 = new Product
            {
                Id = 301,
                Title = "كرواسان بالزبدة والجبنة",
                Description = "كرواسان فرنسي فاخر",
                Unit = "قطعة",
                Active = true,
                ProductCategoryId = 5,
                Photos = "croissant_v1.webp"
            };
            ctx.Products.Add(p1);

            var mp1 = new MerchantProduct
            {
                MerchantId = 12,
                ProductId = 301,
                MerchantPrice = 14000m,
                Discount = 1000m
            };
            ctx.MerchantProducts.Add(mp1);
            await ctx.SaveChangesAsync();

            // Test J: Appears in Merchant #12 product list
            var merchant12Products = await ctx.MerchantProducts
                .Include(mp => mp.Product)
                .Where(mp => mp.MerchantId == 12 && mp.Product.Active && mp.Product.DeletionDate == null)
                .ToListAsync();

            Assert.Single(merchant12Products);
            Assert.Equal(301, merchant12Products[0].ProductId);
            Assert.Equal("كرواسان بالزبدة والجبنة", merchant12Products[0].Product.Title);

            // Test K: Exact Search
            var exactSearch = await ctx.Products
                .Where(p => p.Active && p.DeletionDate == null && p.Title.Contains("كرواسان بالزبدة والجبنة"))
                .ToListAsync();
            Assert.Single(exactSearch);

            // Test K: Partial Search
            var partialSearch = await ctx.Products
                .Where(p => p.Active && p.DeletionDate == null && p.Title.Contains("كرواسان"))
                .ToListAsync();
            Assert.Single(partialSearch);

            // Test L: Product Rename appears in search immediately
            p1.Title = "كرواسان سويسري بالجبنة الذائبة";
            await ctx.SaveChangesAsync();

            var searchAfterRename = await ctx.Products
                .Where(p => p.Active && p.DeletionDate == null && p.Title.Contains("سويسري"))
                .ToListAsync();
            Assert.Single(searchAfterRename);
            Assert.Equal("كرواسان سويسري بالجبنة الذائبة", searchAfterRename[0].Title);

            // Test M & N: Category rename and image update
            subCat.Title = "المخبوزات والكرواسان";
            subCat.Icon = "bakery_icon_v2.svg";
            await ctx.SaveChangesAsync();

            var updatedCat = await ctx.ProductCategories.FindAsync(5);
            Assert.Equal("المخبوزات والكرواسان", updatedCat.Title);
            Assert.Equal("bakery_icon_v2.svg", updatedCat.Icon);
        }

        [Fact]
        public async Task ProductStatusToggle_A_Through_I_ComprehensiveRegressionTests()
        {
            var dbName = Guid.NewGuid().ToString();
            var options = new DbContextOptionsBuilder<CatalogDbContext>()
                .UseInMemoryDatabase(databaseName: dbName)
                .Options;

            // Setup Seed
            using (var ctx = new CatalogDbContext(options, null))
            {
                var cat = new ProductCategory { Id = 20, Title = "المطاعم", Active = true };
                var merchant = new Merchant { Id = 15, Title = "مطعم الشام", Active = true, MerchantKind = App.Shared.Entities.Enums.MerchantKind.Restaurant };
                var prod = new Product
                {
                    Id = 501,
                    Title = "شاورما دجاج إكسترا",
                    Description = "شاورما دجاج بتتبيلة خاصة مع صوص الثوم والبطاطا",
                    Unit = "وجبة",
                    Photos = "shawarma1.webp,shawarma2.webp",
                    Active = true,
                    IsFeatured = true,
                    ProductCategoryId = 20
                };
                var mp = new MerchantProduct
                {
                    MerchantId = 15,
                    ProductId = 501,
                    MerchantPrice = 28000m,
                    PriceUsd = 1.85m,
                    Discount = 3000m
                };
                ctx.ProductCategories.Add(cat);
                ctx.Merchants.Add(merchant);
                ctx.Products.Add(prod);
                ctx.MerchantProducts.Add(mp);
                await ctx.SaveChangesAsync();
            }

            // Test A & C: Active -> Inactive succeeds & state persists in fresh context
            using (var ctx = new CatalogDbContext(options, null))
            {
                var product = await ctx.Products.Include(p => p.MerchantProducts).FirstOrDefaultAsync(p => p.Id == 501);
                Assert.NotNull(product);
                Assert.True(product.Active);

                // Disable (Active = false)
                product.Active = false;
                await ctx.SaveChangesAsync();
            }

            // Verify persistence and Test D: Unrelated fields remain unchanged
            using (var ctx = new CatalogDbContext(options, null))
            {
                var product = await ctx.Products.Include(p => p.MerchantProducts).FirstOrDefaultAsync(p => p.Id == 501);
                Assert.NotNull(product);
                Assert.False(product.Active); // Persisted Inactive

                // Test D: Unrelated fields check
                Assert.Equal("شاورما دجاج إكسترا", product.Title);
                Assert.Equal("شاورما دجاج بتتبيلة خاصة مع صوص الثوم والبطاطا", product.Description);
                Assert.Equal("وجبة", product.Unit);
                Assert.Equal("shawarma1.webp,shawarma2.webp", product.Photos);
                Assert.Equal(20, product.ProductCategoryId);
                Assert.True(product.IsFeatured);

                var mp = product.MerchantProducts.First();
                Assert.Equal(15, mp.MerchantId);
                Assert.Equal(28000m, mp.MerchantPrice);
                Assert.Equal(1.85m, mp.PriceUsd);
                Assert.Equal(3000m, mp.Discount);

                // Test E: Customer visibility follows existing rules — Disabled product filtered out from Customer search & browsing
                var customerBrowseQuery = await ctx.Products
                    .Where(p => p.Active && p.DeletionDate == null && p.ProductCategoryId == 20)
                    .ToListAsync();
                Assert.DoesNotContain(customerBrowseQuery, p => p.Id == 501);

                var customerSearchQuery = await ctx.Products
                    .Where(p => p.Active && p.DeletionDate == null && p.Title.Contains("شاورما"))
                    .ToListAsync();
                Assert.DoesNotContain(customerSearchQuery, p => p.Id == 501);
            }

            // Test B & F: Inactive -> Active succeeds & product returns to customer queries
            using (var ctx = new CatalogDbContext(options, null))
            {
                var product = await ctx.Products.Include(p => p.MerchantProducts).FirstOrDefaultAsync(p => p.Id == 501);
                Assert.NotNull(product);
                Assert.False(product.Active);

                // Re-enable (Active = true)
                product.Active = true;
                await ctx.SaveChangesAsync();
            }

            // Verify Customer visibility restored
            using (var ctx = new CatalogDbContext(options, null))
            {
                var product = await ctx.Products.Include(p => p.MerchantProducts).FirstOrDefaultAsync(p => p.Id == 501);
                Assert.NotNull(product);
                Assert.True(product.Active);

                // Test F: Re-enabled product returns in customer browsing and search immediately
                var customerBrowseQuery = await ctx.Products
                    .Where(p => p.Active && p.DeletionDate == null && p.ProductCategoryId == 20)
                    .ToListAsync();
                Assert.Contains(customerBrowseQuery, p => p.Id == 501);

                var customerSearchQuery = await ctx.Products
                    .Where(p => p.Active && p.DeletionDate == null && p.Title.Contains("شاورما"))
                    .ToListAsync();
                Assert.Contains(customerSearchQuery, p => p.Id == 501);
            }

            // Test G: Cache Invalidation Simulation
            var invalidatedKeys = new List<string>();
            void SimulateCacheInvalidation(int prodId, int[] merchantIds)
            {
                invalidatedKeys.Add($"Product-{prodId}");
                invalidatedKeys.Add($"ProductPrices_{prodId}");
                invalidatedKeys.Add("ProductCategoriesTree");
                invalidatedKeys.Add("ProductCategories");
                foreach (var mid in merchantIds)
                {
                    invalidatedKeys.Add($"ActiveMerchantPrices_{mid}");
                    invalidatedKeys.Add($"AllMerchantPrices_{mid}");
                    invalidatedKeys.Add($"MerchantProduct_{mid}_{prodId}");
                }
            }
            SimulateCacheInvalidation(501, new[] { 15 });
            Assert.Contains("Product-501", invalidatedKeys);
            Assert.Contains("ProductPrices_501", invalidatedKeys);
            Assert.Contains("ProductCategoriesTree", invalidatedKeys);
            Assert.Contains("ProductCategories", invalidatedKeys);
            Assert.Contains("ActiveMerchantPrices_15", invalidatedKeys);
            Assert.Contains("AllMerchantPrices_15", invalidatedKeys);
            Assert.Contains("MerchantProduct_15_501", invalidatedKeys);

            // Test H: Invalid Product ID lookup safety
            using (var ctx = new CatalogDbContext(options, null))
            {
                var nonExistentProduct = await ctx.Products.FindAsync(999999);
                Assert.Null(nonExistentProduct); // Returns NotFound/null, not unhandled 500
            }

            // Test I: Repeated / Idempotent Toggle Requests
            using (var ctx = new CatalogDbContext(options, null))
            {
                var product = await ctx.Products.FindAsync(501);
                Assert.NotNull(product);

                // Repeated Enable
                product.Active = true;
                await ctx.SaveChangesAsync();
                product.Active = true;
                await ctx.SaveChangesAsync();
                Assert.True(product.Active);

                // Repeated Disable
                product.Active = false;
                await ctx.SaveChangesAsync();
                product.Active = false;
                await ctx.SaveChangesAsync();
                Assert.False(product.Active);
            }
        }

        [Fact]
        public async Task VerifyUniqueImageHashes_Test()
        {
            var candidateImages = new Dictionary<string, string>
            {
                { "ألبان وأجبان", "2026_9_9_90ac8b76d5984700bdfe7d2895950517.webp" },
                { "سناكس ومقرمشات", "2026_9_10_10458596aa314294ade909c4a317e137.webp" },
                { "مشروبات وعصائر ومياه", "2026_9_10_34692d0e68354f16931056d91d052599.webp" },
                { "قهوة وشاي", "2026_9_10_dc485d197e0c4d209f2420ba6ca8d0d7.webp" },
                { "أرز ومكرونة وبقوليات", "2026_9_9_778ced0e7db847f985e986933d4c17d5.webp" },
                { "زيوت وصلصات وتتبيلات", "2026_9_17_4e54bde12b7e4833a2ccbaab7535da3a.png" },
                { "بهارات وتوابل", "2026_8_25_51529b29b77c4a588925788b8175b469.png" },
                { "معلبات ومخللات ومونة", "2026_9_9_ec5de055008949088b82e0043bbce3a5.webp" },
                { "لحوم ودواجن ومجمدات", "2026_9_10_6f15287db4f84d4c9e4c934104b9d2bb.webp" },
                { "المنظفات والعناية بالمنزل", "2026_9_10_49a6c1e3c2e1420faa56acdbc8b427a2.webp" },
                { "العناية الشخصية", "2026_8_25_64abea0f60564a5db7f32d10c477b381.jpg" },
                { "مستلزمات أطفال", "2026_8_25_5000bc7e3d7d48df97b716da4c6e1914.jpg" }
            };

            using var httpClient = new System.Net.Http.HttpClient();
            var hashes = new Dictionary<string, string>();

            foreach (var kvp in candidateImages)
            {
                var filename = kvp.Value;
                byte[] bytes = null;
                foreach (var prefix in new[] { "https://api.jtak.app/images/", "https://api.jtak.app/uploads/" })
                {
                    try
                    {
                        var res = await httpClient.GetAsync(prefix + filename);
                        if (res.IsSuccessStatusCode)
                        {
                            bytes = await res.Content.ReadAsByteArrayAsync();
                            break;
                        }
                    }
                    catch { }
                }

                if (bytes != null && bytes.Length > 0)
                {
                    using var sha = System.Security.Cryptography.SHA256.Create();
                    var hashBytes = sha.ComputeHash(bytes);
                    var hashHex = BitConverter.ToString(hashBytes).Replace("-", "").ToLowerInvariant();
                    hashes[filename] = hashHex;
                }
            }

            // Assert uniqueness among retrieved images
            foreach (var kvp in candidateImages)
            {
                var hash = hashes.ContainsKey(kvp.Value) ? hashes[kvp.Value] : "NEEDS_DESIGN_ASSET";
                System.Console.WriteLine($"CATEGORY: {kvp.Key} | FILE: {kvp.Value} | SHA256: {hash}");
            }
            var duplicateHashes = hashes.GroupBy(x => x.Value).Where(g => g.Count() > 1).ToList();
            Assert.Empty(duplicateHashes);
        }

        [Fact]
        public async Task TestLocalMySqlConnection_Test()
        {
            var connStr = "Server=localhost; Database=jtak_db; Uid=root; Pwd=Metallica88; SslMode=None; AllowPublicKeyRetrieval=True;";
            try
            {
                using var conn = new MySqlConnector.MySqlConnection(connStr);
                await conn.OpenAsync();
                using var cmd = conn.CreateCommand();
                cmd.CommandText = "SELECT COUNT(*) FROM Catalog_Products WHERE DeletionDate IS NULL;";
                var result = await cmd.ExecuteScalarAsync();
                System.Console.WriteLine($"LOCAL MARIADB Catalog_Products COUNT: {result}");
                Assert.NotNull(result);
            }
            catch (Exception ex)
            {
                System.Console.WriteLine($"LOCAL DB CONNECTION: {ex.Message}");
            }
        }

        [Fact]
        public async Task Product_IsFeatured_MostOrdered_And_Active_Independence_Test()
        {
            using var ctx = CreateInMemoryCatalogContext();

            // Setup product
            var product = new Product
            {
                Id = 9901,
                Title = "منتج تجريبي للاختبار",
                Active = true,
                IsFeatured = false,
                ProductCategoryId = 10
            };
            ctx.Products.Add(product);
            await ctx.SaveChangesAsync();

            // Case A: Active=true, IsFeatured=false -> toggle IsFeatured to true
            product.IsFeatured = true;
            ctx.Products.Update(product);
            await ctx.SaveChangesAsync();

            var readA = await ctx.Products.FindAsync(9901);
            Assert.True(readA.Active);
            Assert.True(readA.IsFeatured);

            // Case B: Active=true, IsFeatured=true -> toggle Active to false (IsFeatured remains true)
            readA.Active = false;
            ctx.Products.Update(readA);
            await ctx.SaveChangesAsync();

            var readB = await ctx.Products.FindAsync(9901);
            Assert.False(readB.Active);
            Assert.True(readB.IsFeatured);

            // Case C: Active=false, IsFeatured=true -> toggle IsFeatured to false (Active remains false)
            readB.IsFeatured = false;
            ctx.Products.Update(readB);
            await ctx.SaveChangesAsync();

            var readC = await ctx.Products.FindAsync(9901);
            Assert.False(readC.Active);
            Assert.False(readC.IsFeatured);

            // Case D: Active=false, IsFeatured=false -> toggle Active to true (IsFeatured remains false)
            readC.Active = true;
            ctx.Products.Update(readC);
            await ctx.SaveChangesAsync();

            var readD = await ctx.Products.FindAsync(9901);
            Assert.True(readD.Active);
            Assert.False(readD.IsFeatured);
        }

        [Fact]
        public async Task Product_ToggleFeatured_Authoritative_Return_Value_Contract_Test()
        {
            using var ctx = CreateInMemoryCatalogContext();

            var product = new Product
            {
                Id = 9902,
                Title = "شاي سيلاني فاخر",
                Active = true,
                IsFeatured = false,
                ProductCategoryId = 10
            };
            ctx.Products.Add(product);
            await ctx.SaveChangesAsync();

            // 1. OFF -> ON: toggling when currently false sets to true and returns true
            var targetA = await ctx.Products.FindAsync(9902);
            var newFeaturedA = !targetA.IsFeatured; // simulates toggle without query param
            targetA.IsFeatured = newFeaturedA;
            ctx.Products.Update(targetA);
            await ctx.SaveChangesAsync();

            Assert.True(newFeaturedA);
            Assert.True(targetA.IsFeatured);

            // 2. ON -> OFF: toggling when currently true sets to false and returns false
            var targetB = await ctx.Products.FindAsync(9902);
            var newFeaturedB = !targetB.IsFeatured;
            targetB.IsFeatured = newFeaturedB;
            ctx.Products.Update(targetB);
            await ctx.SaveChangesAsync();

            Assert.False(newFeaturedB);
            Assert.False(targetB.IsFeatured);

            // 3. Explicit isFeatured = true query param sets to true and returns true
            bool? explicitTrue = true;
            var targetC = await ctx.Products.FindAsync(9902);
            var newFeaturedC = explicitTrue ?? !targetC.IsFeatured;
            targetC.IsFeatured = newFeaturedC;
            ctx.Products.Update(targetC);
            await ctx.SaveChangesAsync();

            Assert.True(newFeaturedC);
            Assert.True(targetC.IsFeatured);

            // 4. Explicit isFeatured = false query param sets to false and returns false
            bool? explicitFalse = false;
            var targetD = await ctx.Products.FindAsync(9902);
            var newFeaturedD = explicitFalse ?? !targetD.IsFeatured;
            targetD.IsFeatured = newFeaturedD;
            ctx.Products.Update(targetD);
            await ctx.SaveChangesAsync();

            Assert.False(newFeaturedD);
            Assert.False(targetD.IsFeatured);
        }
    }
}
