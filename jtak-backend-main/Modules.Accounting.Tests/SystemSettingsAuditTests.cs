using App.ApiControllers.V1.Admin;
using App.ApiModels;
using App.Catalog.Data;
using App.Shared.Data.App;
using App.Shared.Data.MultiContext;
using App.Shared.Entities;
using App.Shared.Entities.Domain;
using App.Shared.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging.Abstractions;
using Modules.Catalog.Entities;
using Modules.Catalog.Services;
using Modules.Orders.Entities;
using Moq;
using Solf.Models;
using Xunit;

namespace Modules.Accounting.Tests;

public class SystemSettingsAuditTests
{

 sealed class Fixture : IDisposable
 {
  public SqliteConnection Connection = new("Data Source=:memory:");
  public AppDbContext App;
  public CatalogDbContext Catalog;
  public MemoryCache Cache = new(new MemoryCacheOptions());
  public GenericSettingService Settings;
  public Mock<IMerchantService> Merchants = new();
  public Mock<IAdminAuditService> Audit = new();
  public Fixture()
  {
   Connection.Open();
   App = new(new DbContextOptionsBuilder<AppDbContext>().UseSqlite(Connection).Options, null);
   App.Database.EnsureCreated();
   Catalog = new(new DbContextOptionsBuilder<CatalogDbContext>().UseSqlite("Data Source=:memory:").Options, null);
   Settings = new(new TrackableRepository<GenericSetting, AppDbContext>(App), Cache, new AppUnitOfWork(App));
  }
  public SettingsController Controller() => new(null, null, Merchants.Object, Settings, new AppUnitOfWork(App), null,
   NullLogger<SettingsController>.Instance, Audit.Object, catalogUnitOfWork: new CatalogUnitOfWork(Catalog));
  public void Dispose() { Catalog.Dispose(); App.Dispose(); Connection.Dispose(); Cache.Dispose(); }
 }

 [Fact] public async Task ReadingCachedMissingValueDoesNotHidePersistedSetting()
 {
  using var f = new Fixture();
  await f.Settings.SetValue("existing", "value"); f.Cache.Clear();
  Assert.Null(f.Settings.GetCachedValue<string>("existing"));
  Assert.Equal("value", await f.Settings.GetValue<string>("existing"));
 }
 [Fact] public async Task ChangingRepresentationInvalidatesStringAndObjectReaders()
 {
  using var f = new Fixture();
  await f.Settings.SetValue("page", "legacy");
  Assert.Null(await f.Settings.GetValue<PageVm>("page"));
  await f.Settings.SetValue("page", new PageVm { Body = "fresh" });
  Assert.Equal("fresh", (await f.Settings.GetValue<PageVm>("page")).Body);
  Assert.Null(await f.Settings.GetValue<string>("page"));
 }
 [Fact] public async Task EditingReturnedSettingsNeverMutatesSharedCache()
 {
  using var f = new Fixture();
  var setting = new SystemContactSettings(); await f.Settings.SetValue("contact", setting);
  setting.PhoneNumber = "bad";
  var read = await f.Settings.GetValue<SystemContactSettings>("contact"); read.PhoneNumber = "other";
  Assert.Equal("0985615705", (await f.Settings.GetValue<SystemContactSettings>("contact")).PhoneNumber);
 }
 [Fact] public async Task NullCanBePersistedAndCachedWithoutAnExceptionAfterSave()
 {
  using var f = new Fixture(); await f.Settings.SetValue<string>("nullable", null);
  Assert.Null(await f.Settings.GetValue<string>("nullable"));
  f.Settings.SetCachedValue<string>("nullable", null);
  Assert.Null(f.Settings.GetCachedValue<string>("nullable"));
 }
 [Fact] public async Task RolledBackSettingsNeverRemainInMemoryCache()
 {
  using var f = new Fixture(); await f.Settings.SetValue("rate", 100m);
  await using (var tx = await f.App.Database.BeginTransactionAsync())
  { await f.Settings.SetValue("rate", 200m); Assert.Equal(200m, await f.Settings.GetValue<decimal>("rate")); await tx.RollbackAsync(); }
  f.App.ChangeTracker.Clear(); Assert.Equal(100m, await f.Settings.GetValue<decimal>("rate"));
 }
 [Theory] [InlineData("0912345678", "+963912345678", "0912 345 678")]
 [InlineData("+201234567890", "+201234567890", "+201234567890")]
 [InlineData("201234567890", "+201234567890", "+201234567890")]
 public void EditedNumberReplacesOldDialAndDisplayValues(string phone, string international, string formatted)
 {
  var model = new SystemContactSettings { PhoneNumber = phone, WhatsAppNumber = "963999111222" };
  model.Normalize(); Assert.Equal(international, model.PhoneInternational); Assert.Equal(formatted, model.PhoneFormatted);
  Assert.Equal("963999111222", model.WhatsAppNumber); Assert.Null(model.ValidationError());
 }
 [Theory] [InlineData("abc0912345678")] [InlineData("+++++++")] [InlineData("0000000000")]
 [InlineData("123")] [InlineData("+1234567890123456")]
 public async Task InvalidContactPhoneCannotWrite(string phone)
 {
  using var f = new Fixture(); var result = await f.Controller().SetContact(new() { PhoneNumber = phone });
  Assert.IsType<BadRequestObjectResult>(result.Result);
  Assert.Null(await f.Settings.GetValue<SystemContactSettings>(SystemContactSettings.Key));
 }
 [Theory] [InlineData("javascript:alert(1)")] [InlineData("ftp://example.com")]
 [InlineData("https://user:password@example.com")]
 public async Task UnsafeSocialLinksCannotWrite(string url)
 {
  using var f = new Fixture(); Assert.IsType<BadRequestObjectResult>((await f.Controller().SetContact(new() { FacebookUrl = url })).Result);
 }
 [Fact] public async Task ContactSaveSuccessIsNotTurnedIntoFailureByLogging()
 {
  using var f = new Fixture(); f.Audit.Setup(a => a.LogAsync(It.IsAny<AdminAuditLogEntry>())).ThrowsAsync(new Exception("audit offline"));
  Assert.IsType<OkObjectResult>((await f.Controller().SetContact(new() { PhoneNumber = "0912345678", FacebookUrl = "" })).Result);
  var setting = await f.Settings.GetValue<SystemContactSettings>(SystemContactSettings.Key);
  Assert.Equal("+963912345678", setting.PhoneInternational); Assert.Equal("", setting.FacebookUrl);
 }
 [Theory] [InlineData(null)] [InlineData("")] [InlineData("<p>&nbsp;</p>")] [InlineData("<p> </p>")]
 public async Task BlankLegalPagesAreRejected(string? body)
 {
  using var f = new Fixture(); var pages = new PagesController(f.Settings);
  Assert.IsType<BadRequestObjectResult>((await pages.TermsAndConditions(new() { Body = body }, "delivery")).Result);
  Assert.IsType<BadRequestObjectResult>((await pages.PrivacyPolicy(new() { Body = body })).Result);
  Assert.IsType<BadRequestObjectResult>((await pages.PaymentPolicy(new() { Body = body })).Result);
 }
 [Fact] public async Task AdminNeverClaimsCustomerTermsAreSavedForAnotherApp()
 {
  using var f = new Fixture(); var pages = new PagesController(f.Settings);
  await pages.TermsAndConditions(new() { Body = "Customer terms" }, "customer");
  Assert.True(string.IsNullOrEmpty((await pages.TermsAndConditions("delivery")).Value.Body));
  Assert.True(string.IsNullOrEmpty((await pages.TermsAndConditions("warehouse")).Value.Body));
  await pages.TermsAndConditions(new() { Body = "Courier terms" }, "delivery");
  Assert.Equal("Courier terms", (await pages.TermsAndConditions("delivery")).Value.Body);
  Assert.Equal("Customer terms", (await pages.TermsAndConditions("customer")).Value.Body);
 }
 [Fact] public async Task LegalPageSaveLogsTheAppScopeAndSurvivesAuditFailure()
 {
  using var f = new Fixture(); f.Audit.Setup(a => a.LogAsync(It.IsAny<AdminAuditLogEntry>())).ThrowsAsync(new Exception());
  var page = await new PagesController(f.Settings, f.Audit.Object).TermsAndConditions(new() { Body = "Merchant policy" }, "warehouse");
  Assert.NotNull(page.Value); f.Audit.Verify(a => a.LogAsync(It.Is<AdminAuditLogEntry>(e => e.EntityId == "TermsAndConditions_Warehouse" && e.Module == "Pages")), Times.Once);
 }
 [Theory] [InlineData(0.001)] [InlineData(-1)] [InlineData(100000001)]
 public void DriverMoneyMustHaveTwoDecimalsAndABound(decimal amount)
 { Assert.False(new DriverPricingSetting { FixedAmount = amount }.IsValid); Assert.False(new DriverPricingSetting { DistanceBaseFee = amount }.IsValid); }
 [Theory] [InlineData(-1)] [InlineData(0)] [InlineData(100000001)] [InlineData(1.1234567)]
 public async Task InvalidExchangeRateNeverSavesSettings(decimal rate)
 {
  using var f = new Fixture(); Assert.IsType<BadRequestObjectResult>((await f.Controller().SetSettings(new() { UsdToSypExchangeRate = rate })).Result);
  Assert.Null(await f.Settings.GetValue<UsdExchangeRateSetting>(UsdExchangeRateSetting.Key));
 }
 [Theory] [InlineData(false)] [InlineData(true)]
 public async Task ExchangeRateAndProductPricesCommitOrRollBackTogether(bool fail)
 {
  using var f = new Fixture(); await f.Settings.SetValue(UsdExchangeRateSetting.Key, new UsdExchangeRateSetting { Rate = 100m });
  await f.Settings.SetValue("simulated_product", 100m);
  var table = f.App.Model.FindEntityType(typeof(GenericSetting))!.GetTableName();
  f.Merchants.Setup(m => m.RepriceUsdDenominatedProducts(200m)).Returns(async () => {
   await f.Catalog.Database.ExecuteSqlRawAsync($"UPDATE \"{table}\" SET \"Value\" = '200' WHERE \"Key\" = 'simulated_product'");
   using var readerDb = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>().UseSqlite("Data Source=:memory:").Options, null);
   var reader = new GenericSettingService(new TrackableRepository<GenericSetting, AppDbContext>(readerDb), f.Cache, new AppUnitOfWork(readerDb));
   // A concurrent reader may have obtained the old rate before the transaction committed.
   reader.SetCachedValue(UsdExchangeRateSetting.Key, new UsdExchangeRateSetting { Rate = 100m });
   if (fail) throw new Exception("repricing failed"); return 1;
  });
  var result = await f.Controller().SetSettings(new() { UsdToSypExchangeRate = 200m });
  f.App.ChangeTracker.Clear();
  Assert.Equal(fail ? 100m : 200m, (await f.Settings.GetValue<UsdExchangeRateSetting>(UsdExchangeRateSetting.Key)).Rate);
  f.Cache.Clear(); Assert.Equal(fail ? 100m : 200m, await f.Settings.GetValue<decimal>("simulated_product"));
  if (fail) Assert.IsType<BadRequestObjectResult>(result.Result); else Assert.True(result.Value);
  f.Merchants.Verify(m => m.InvalidateRepricedUsdCache(), fail ? Times.Never() : Times.Once());
  Assert.Null(f.Catalog.Database.CurrentTransaction); Assert.NotSame(f.Connection, f.Catalog.Database.GetDbConnection());
 }
 [Fact] public async Task NonSuccessAuditFilterMatchesSummaryAndUpdateMatchesSavedActions()
 {
  using var db = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, null);
  var service = new AdminAuditService(db, new HttpContextAccessor());
  foreach (var action in new[] { "Edit", "UpdateContactSettings", "UpdateDriverPricing", "Disable", "Enable" })
   await service.LogAsync(new() { Module = "Settings", Action = action, Result = action == "Edit" ? "Success" : "Warning" });
  var failed = await service.GetDataTableAsync(new MetronicTable { PageNumber = 1, PageSize = 10 }, new() { Result = "Failed" });
  Assert.Equal((await service.GetSummaryAsync()).FailureCount, failed.TotalRecords);
  Assert.Equal(3, (await service.GetDataTableAsync(new(), new() { Action = "Update" })).TotalRecords);
  Assert.Equal(1, (await service.GetDataTableAsync(new(), new() { Action = "DisableUser" })).TotalRecords);
  Assert.Equal(1, (await service.GetDataTableAsync(new(), new() { Action = "EnableUser" })).TotalRecords);
 }
 [Fact] public async Task EmptyAuditSummaryDoesNotInventAnAdminOrModule()
 {
  using var f = new Fixture(); var summary = await new AdminAuditService(f.App, new HttpContextAccessor()).GetSummaryAsync();
  Assert.Equal("", summary.TopAdmin); Assert.Equal("", summary.TopModule);
 }
 [Fact] public async Task ForwardedHeaderCannotSpoofAuditSourceAddress()
 {
  using var f = new Fixture(); var http = new DefaultHttpContext(); http.Connection.RemoteIpAddress = System.Net.IPAddress.Parse("127.0.0.1");
  http.Request.Headers["X-Forwarded-For"] = "10.0.0.123";
  await new AdminAuditService(f.App, new HttpContextAccessor { HttpContext = http }).LogAsync(new() { Module = "Settings", Action = "Update" });
  Assert.Equal("127.0.0.1", f.App.AdminAuditLogs.Single().IpAddress);
 }
 [Fact] public async Task InvalidAuditDateRangeReturnsHelpfulError()
 {
  var audit = new Mock<IAdminAuditService>();
  Assert.IsType<BadRequestObjectResult>((await new AuditLogsController(audit.Object).DataTable(new(), fromDate: new(2026, 10, 4), toDate: new(2026, 10, 3))).Result);
  audit.Verify(a => a.GetDataTableAsync(It.IsAny<MetronicTable>(), It.IsAny<AdminAuditLogFilter>()), Times.Never);
 }
 [Fact] public async Task AllThreePublicAppsReadTheirOwnTermsAndTheSamePaymentPolicy()
 {
  using var f = new Fixture(); var admin = new PagesController(f.Settings);
  foreach (var scope in new[] { "customer", "delivery", "warehouse" })
   await admin.TermsAndConditions(new() { Body = scope + " terms" }, scope);
  await admin.PaymentPolicy(new() { Body = "Shared payment policy" });
  var customer = new App.ApiControllers.V1.Customer.PagesController(f.Settings, null, null, null);
  var delivery = new App.ApiControllers.V1.Delivery.PagesController(f.Settings);
  var warehouse = new App.ApiControllers.V1.Warehouse.PagesController(f.Settings);
  Assert.Equal("customer terms", (await customer.TermsAndConditions()).Value.Body);
  Assert.Equal("delivery terms", (await delivery.TermsAndConditions()).Body);
  Assert.Equal("warehouse terms", (await warehouse.TermsAndConditions()).Body);
  Assert.Equal("Shared payment policy", (await customer.PaymentPolicy()).Value.Body);
  Assert.Equal("Shared payment policy", (await delivery.PaymentPolicy()).Body);
  Assert.Equal("Shared payment policy", (await warehouse.PaymentPolicy()).Body);
 }
 [Fact] public async Task FinancialSettingSavesSurviveAuditFailure()
 {
  using var f = new Fixture(); f.Audit.Setup(a => a.LogAsync(It.IsAny<AdminAuditLogEntry>())).ThrowsAsync(new Exception());
  Assert.IsType<OkObjectResult>((await f.Controller().SetDriverPricing(new() { FixedAmount = 40m })).Result);
  Assert.IsType<OkObjectResult>((await f.Controller().SetErrandDriverEarning(new() { Amount = 75m })).Result);
  Assert.IsType<OkObjectResult>(await f.Controller().SetJtakMarketCourierPay(new()));
  Assert.Equal(40m, (await f.Settings.GetValue<DriverPricingSetting>(DriverPricingSetting.Key)).FixedAmount);
  Assert.Equal(75m, (await f.Settings.GetValue<ErrandDriverEarningSetting>(ErrandDriverEarningSetting.Key)).Amount);
 }
 [Fact] public void DistanceRatesRetainSixDecimalsWhileFixedMoneyUsesTwo()
 {
  Assert.True(new DriverPricingSetting { DistanceRatePerUnit = 1609.344m, CustomerRatePerKm = 45.000001m }.IsValid);
  Assert.False(new DriverPricingSetting { CustomerRatePerKm = 45.0000001m }.IsValid);
 }
 [Fact] public async Task LocalizedCacheReturnsTheFirstLoadedValueAndKeepsLanguagesSeparate()
 {
  using var cache = new MemoryCache(new MemoryCacheOptions());
  Assert.Equal("Arabic", await cache.GetValue("page", "ar", () => Task.FromResult("Arabic")));
  Assert.Equal("English", await cache.GetValue("page", "en", () => Task.FromResult("English")));
 }
 [Fact] public async Task OldPriceReadCannotRepopulateTheCacheAfterInvalidation()
 {
  using var cache = new MemoryCache(new MemoryCacheOptions()); var pending = new TaskCompletionSource<decimal>();
  var oldRead = cache.GetValue("ProductPrices_1", null, () => pending.Task);
  cache.InvalidateValue("ProductPrices_1");
  Assert.Equal(200m, await cache.GetValue("ProductPrices_1", null, () => Task.FromResult(200m)));
  pending.SetResult(100m); Assert.Equal(100m, await oldRead);
  Assert.Equal(200m, await cache.GetValue("ProductPrices_1", null, () => Task.FromResult(999m)));
 }
 [Fact] public async Task RepricingInvalidatesEveryMerchantPriceViewAfterCommit()
 {
  using var db = new CatalogDbContext(new DbContextOptionsBuilder<CatalogDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, null);
  using var cache = new MemoryCache(new MemoryCacheOptions());
  db.MerchantProducts.Add(new() { MerchantId = 1, ProductId = 10, MerchantPrice = 100m, PriceUsd = 1m });
  await db.SaveChangesAsync();
  var merchant = new MerchantService(new TrackableRepository<Modules.Catalog.Entities.Merchant, CatalogDbContext>(db),
   new TrackableRepository<MerchantProduct, CatalogDbContext>(db), new CatalogUnitOfWork(db), new Mock<IGenericSettingService>().Object, cache);
  Assert.Equal(1, await merchant.RepriceUsdDenominatedProducts(200m));
  var keys = new[] { "ProductPrices_10", "MerchantProduct_1_10", "ActiveMerchantPrices_1", "AllMerchantPrices_1" };
  foreach (var key in keys) cache.Set(key, "old reader");
  merchant.InvalidateRepricedUsdCache();
  foreach (var key in keys) Assert.False(cache.TryGetValue(key, out _));
 }
 [Theory] [InlineData("TermsAndConditions", "الشروط والأحكام")]
 [InlineData("TermsAndConditions_Delivery", "الشروط والأحكام")]
 [InlineData("TermsAndConditions_Warehouse", "الشروط والأحكام")]
 [InlineData("PrivacyPolicy", "سياسة الخصوصية")]
 [InlineData("PaymentPolicy", "سياسة الدفع")]
 [InlineData("About", "عن جيتك")]
 public async Task TechnicalPageKeysAreNeverShownAsArabicAppHeadings(string key, string expected)
 {
  using var f = new Fixture(); await f.Settings.SetValue(key, new PageVm { Title = key, Body = "محتوى الصفحة" }, "ar");
  Assert.Equal(expected, (await PageSettingsReader.GetPage(f.Settings, key, "ar")).Title);
 }
 [Fact] public async Task AllPublicRoutesUseTheSameLegacyFallbackWhileAdminShowsExplicitAppContent()
 {
  using var f = new Fixture(); var admin = new PagesController(f.Settings);
  await admin.TermsAndConditions(new PageVm { Body = "General terms" });
  Assert.Equal("General terms", (await new App.ApiControllers.V1.Customer.PagesController(f.Settings, null, null, null).TermsAndConditions("delivery")).Value.Body);
  Assert.Equal("General terms", (await new App.ApiControllers.V1.Delivery.PagesController(f.Settings).TermsAndConditions()).Body);
  Assert.Equal("General terms", (await new App.ApiControllers.V1.Warehouse.PagesController(f.Settings).TermsAndConditions()).Body);
  Assert.True(string.IsNullOrEmpty((await admin.TermsAndConditions("delivery")).Value.Body));
 }
 [Fact] public async Task LegacyCamelCaseSettingsReadThePersistedValuesInsteadOfDefaults()
 {
  using var f = new Fixture();
  await f.Settings.SetValue("legacy_contact", new { phoneNumber = "0912345678", supportEmail = "custom@jtak.app" });
  var contact = await f.Settings.GetValue<SystemContactSettings>("legacy_contact");
  Assert.Equal("0912345678", contact.PhoneNumber); Assert.Equal("custom@jtak.app", contact.SupportEmail);
  await f.Settings.SetValue("PrivacyPolicy", new { title = "خصوصية", body = "المحتوى الصحيح" }, "ar");
  Assert.Equal("المحتوى الصحيح", (await PageSettingsReader.GetPage(f.Settings, "PrivacyPolicy", "ar")).Body);
 }
}
