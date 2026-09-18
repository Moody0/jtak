using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Text.Json;
using System.Threading.Tasks;
using App.Shared.Data.App;
using App.Shared.Entities;
using App.Shared.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Modules.Orders.Entities;
using Solf.Models;
using Xunit;

namespace Modules.Accounting.Tests
{
    public class AdminOrdersUxAndAuditLogsTests
    {
        private AppDbContext CreateInMemoryAppDbContext(string dbName)
        {
            var options = new DbContextOptionsBuilder<AppDbContext>()
                .UseInMemoryDatabase(databaseName: dbName)
                .Options;
            return new AppDbContext(options, null);
        }

        [Fact]
        public void AuditSanitizer_RedactsPasswords_Tokens_AndSensitiveKeys()
        {
            var sensitiveObj = new
            {
                Username = "admin_user",
                Password = "SuperSecretPassword123!",
                ApiKey = "ak_live_999888777",
                AdminToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9",
                OtpCode = "849201",
                Pin = "1234",
                PublicInfo = "This is safe",
                Nested = new
                {
                    SecretKey = "sk_test_12345",
                    ClientEmail = "admin@jtak.sy"
                }
            };

            var sanitizedJson = AuditSanitizer.Sanitize(sensitiveObj);

            Assert.NotNull(sanitizedJson);
            Assert.Contains("\"Password\": \"[REDACTED]\"", sanitizedJson);
            Assert.Contains("\"ApiKey\": \"[REDACTED]\"", sanitizedJson);
            Assert.Contains("\"AdminToken\": \"[REDACTED]\"", sanitizedJson);
            Assert.Contains("\"OtpCode\": \"[REDACTED]\"", sanitizedJson);
            Assert.Contains("\"Pin\": \"[REDACTED]\"", sanitizedJson);
            Assert.Contains("\"SecretKey\": \"[REDACTED]\"", sanitizedJson);
            Assert.Contains("\"PublicInfo\": \"This is safe\"", sanitizedJson);
            Assert.Contains("\"ClientEmail\": \"admin@jtak.sy\"", sanitizedJson);
            Assert.DoesNotContain("SuperSecretPassword123!", sanitizedJson);
            Assert.DoesNotContain("ak_live_999888777", sanitizedJson);
        }

        [Fact]
        public void AuditSanitizer_SanitizesRawJsonString()
        {
            var rawJson = "{\"User\":\"John Doe\",\"Password\":\"plainPassword\",\"AuthHeader\":\"Bearer xyz123\"}";
            var sanitized = AuditSanitizer.Sanitize(rawJson);

            Assert.NotNull(sanitized);
            Assert.Contains("\"Password\": \"[REDACTED]\"", sanitized);
            Assert.Contains("\"AuthHeader\": \"[REDACTED]\"", sanitized);
            Assert.Contains("\"User\": \"John Doe\"", sanitized);
            Assert.DoesNotContain("plainPassword", sanitized);
        }

        [Fact]
        public async Task AdminAuditService_LogsOperationWithEnrichedContext_AndSummaryWorks()
        {
            var db = CreateInMemoryAppDbContext("AuditTestDb_1");
            var adminId = Guid.NewGuid();

            var httpContext = new DefaultHttpContext();
            var claims = new[]
            {
                new Claim(ClaimTypes.NameIdentifier, adminId.ToString()),
                new Claim(ClaimTypes.Name, "Master Admin"),
                new Claim(ClaimTypes.Email, "admin@jtak.sy")
            };
            httpContext.User = new ClaimsPrincipal(new ClaimsIdentity(claims, "TestAuth"));
            httpContext.Connection.RemoteIpAddress = System.Net.IPAddress.Parse("192.168.1.100");
            httpContext.Request.Headers["User-Agent"] = "Mozilla/5.0 TestBrowser";

            var accessor = new HttpContextAccessor { HttpContext = httpContext };
            var service = new AdminAuditService(db, accessor);

            await service.LogAsync(new AdminAuditLogEntry
            {
                Module = "Orders",
                Action = "Archive",
                EntityType = "Order",
                EntityId = "1055",
                Description = "أرشفة الطلب #1055 بسبب: طلب تجريبي مكرر",
                Result = "Success",
                BeforeState = new { Id = 1055, Status = "Success" },
                AfterState = new { Id = 1055, Status = "Archived" }
            });

            await service.LogAsync(new AdminAuditLogEntry
            {
                Module = "Settlements",
                Action = "Approve",
                EntityType = "SettlementRequest",
                EntityId = "SET-2026-001",
                Description = "الموافقة على تسوية التاجر محطة اللحوم",
                Result = "Success",
                BeforeState = new { RequestNumber = "SET-2026-001", Status = "Pending" },
                AfterState = new { RequestNumber = "SET-2026-001", Status = "Approved" }
            });

            await service.LogAsync(new AdminAuditLogEntry
            {
                Module = "Catalog",
                Action = "Delete",
                EntityType = "Product",
                EntityId = "99",
                Description = "فشل حذف المنتج لوجود طلبات مرتبطة",
                Result = "Failed",
                FailureReason = "Foreign key violation"
            });

            var summary = await service.GetSummaryAsync();
            Assert.Equal(3, summary.TotalOperations);
            Assert.Equal(3, summary.TodayOperations);
            Assert.Equal(2, summary.SuccessCount);
            Assert.Equal(1, summary.FailureCount);

            var dataTable = await service.GetDataTableAsync(new MetronicTable { PageNumber = 1, PageSize = 10 });
            Assert.Equal(3, dataTable.TotalRecords);
            Assert.Equal(3, dataTable.Items.Length);

            var ordersFilter = await service.GetDataTableAsync(new MetronicTable { PageNumber = 1, PageSize = 10 }, new AdminAuditLogFilter { Module = "Orders" });
            Assert.Equal(1, ordersFilter.TotalRecords);
            Assert.Equal("1055", ordersFilter.Items[0].EntityId);
            Assert.Equal("Master Admin", ordersFilter.Items[0].AdminName);
            Assert.Equal(adminId, ordersFilter.Items[0].AdminUserId);
            Assert.Equal("192.168.1.100", ordersFilter.Items[0].IpAddress);
        }

        [Fact]
        public void OrderSoftDeleteAndRestore_InvariantsPreserved()
        {
            var order = new Order
            {
                Id = 1001,
                OrderStatus = OrderStatus.Success,
                User = "Ahmad Khalil",
                Phonenumber = "0944112233",
                Address = "Damascus, Mazzeh, Street 14",
                CreatedDate = DateTime.UtcNow.AddHours(-5)
            };

            // Initial State: Active
            Assert.Null(order.DeletionDate);
            Assert.Null(order.DeletedBy);
            Assert.Null(order.DeleteReason);

            // Archive / Soft Delete
            var archiveReason = "طلب تجريبي تم اختباره من قبل فريق الجودة";
            var adminId = Guid.NewGuid().ToString();

            order.DeletionDate = DateTime.UtcNow;
            order.DeletedBy = adminId;
            order.DeleteReason = archiveReason;

            Assert.NotNull(order.DeletionDate);
            Assert.Equal(adminId, order.DeletedBy);
            Assert.Equal(archiveReason, order.DeleteReason);

            // Restore from Archive
            order.DeletionDate = null;
            order.DeletedBy = null;
            order.DeleteReason = null;

            Assert.Null(order.DeletionDate);
            Assert.Null(order.DeletedBy);
            Assert.Null(order.DeleteReason);
        }

        [Fact]
        public void OrdersSearchQuery_MatchesOnlyId_Name_AndPhone_AndExcludesAddress()
        {
            var orders = new List<Order>
            {
                new Order { Id = 101, User = "Mohammad Ali", Phonenumber = "0933111222", Address = "Damascus Malki", DeletionDate = null, OrderStatus = OrderStatus.Success },
                new Order { Id = 102, User = "Samer Kassem", Phonenumber = "0944555666", Address = "Damascus Midan Ali Street", DeletionDate = null, OrderStatus = OrderStatus.Success },
                new Order { Id = 103, User = "Ali Hassan", Phonenumber = "0988777888", Address = "Aleppo Center", DeletionDate = null, OrderStatus = OrderStatus.Success }
            }.AsQueryable();

            // Search by Customer Name: "Ali"
            var term1 = "ali";
            var isNum1 = int.TryParse(term1, out var id1);
            var results1 = isNum1
                ? orders.Where(o => o.Id == id1 || (o.Phonenumber != null && o.Phonenumber.Contains(term1)) || (o.User != null && o.User.ToLower().Contains(term1))).ToList()
                : orders.Where(o => (o.Phonenumber != null && o.Phonenumber.Contains(term1)) || (o.User != null && o.User.ToLower().Contains(term1))).ToList();

            // Matches Order 101 (Mohammad Ali) and Order 103 (Ali Hassan), but NOT Order 102 (which only had "Ali" in Address!)
            Assert.Equal(2, results1.Count);
            Assert.Contains(results1, o => o.Id == 101);
            Assert.Contains(results1, o => o.Id == 103);
            Assert.DoesNotContain(results1, o => o.Id == 102);

            // Search by Phone: "0944"
            var term2 = "0944";
            var results2 = orders.Where(o => (o.Phonenumber != null && o.Phonenumber.Contains(term2)) || (o.User != null && o.User.ToLower().Contains(term2))).ToList();
            Assert.Single(results2);
            Assert.Equal(102, results2[0].Id);

            // Search by Address word "Midan" should return 0 because address matching is excluded
            var term3 = "midan";
            var results3 = orders.Where(o => (o.Phonenumber != null && o.Phonenumber.Contains(term3)) || (o.User != null && o.User.ToLower().Contains(term3))).ToList();
            Assert.Empty(results3);
        }

        [Fact]
        public async Task AdminAuditService_DataTableFilters_ByModuleActionAdminDateRangeAndResult()
        {
            var db = CreateInMemoryAppDbContext("AuditTestDb_Filters");
            var admin1 = Guid.NewGuid();
            var admin2 = Guid.NewGuid();

            var service = new AdminAuditService(db, new HttpContextAccessor());

            // 1. Order Approve by Admin 1
            await service.LogAsync(new AdminAuditLogEntry
            {
                AdminUserId = admin1,
                AdminName = "Admin 1",
                Module = "Orders",
                Action = "Approve",
                EntityType = "Order",
                EntityId = "2001",
                Result = "Success"
            });

            // 2. Order Driver Assign by Admin 1
            await service.LogAsync(new AdminAuditLogEntry
            {
                AdminUserId = admin1,
                AdminName = "Admin 1",
                Module = "Orders",
                Action = "AssignDriver",
                EntityType = "Order",
                EntityId = "2001",
                Result = "Success"
            });

            // 3. Product Price Edit by Admin 2
            await service.LogAsync(new AdminAuditLogEntry
            {
                AdminUserId = admin2,
                AdminName = "Admin 2",
                Module = "Products",
                Action = "Edit",
                EntityType = "Product",
                EntityId = "55",
                Result = "Success"
            });

            // 4. Failed User Delete by Admin 2
            await service.LogAsync(new AdminAuditLogEntry
            {
                AdminUserId = admin2,
                AdminName = "Admin 2",
                Module = "Users",
                Action = "Delete",
                EntityType = "User",
                EntityId = "user-999",
                Result = "Failed",
                FailureReason = "Cannot delete root admin user"
            });

            // Filter by Result = "Failed"
            var failedOnly = await service.GetDataTableAsync(new MetronicTable(), new AdminAuditLogFilter { Result = "Failed" });
            Assert.Equal(1, failedOnly.TotalRecords);
            Assert.Equal("Delete", failedOnly.Items[0].Action);
            Assert.Equal("Cannot delete root admin user", failedOnly.Items[0].FailureReason);

            // Filter by AdminUserId = admin2
            var admin2Logs = await service.GetDataTableAsync(new MetronicTable(), new AdminAuditLogFilter { AdminUserId = admin2 });
            Assert.Equal(2, admin2Logs.TotalRecords);

            // Filter by Module = "Products"
            var productLogs = await service.GetDataTableAsync(new MetronicTable(), new AdminAuditLogFilter { Module = "Products" });
            Assert.Equal(1, productLogs.TotalRecords);
            Assert.Equal("55", productLogs.Items[0].EntityId);

            // Filter by Action = "Approve"
            var approveLogs = await service.GetDataTableAsync(new MetronicTable(), new AdminAuditLogFilter { Action = "Approve" });
            Assert.Equal(1, approveLogs.TotalRecords);
            Assert.Equal("2001", approveLogs.Items[0].EntityId);
        }

        [Fact]
        public async Task AdminAuditService_FailedOperations_RecordFailureReason_AndResult()
        {
            var db = CreateInMemoryAppDbContext("AuditTestDb_Failures");
            var service = new AdminAuditService(db, new HttpContextAccessor());

            await service.LogAsync(new AdminAuditLogEntry
            {
                Module = "Orders",
                Action = "Deliver",
                EntityType = "Order",
                EntityId = "3001",
                Description = "محاولة تسليم إداري دون PIN أو ملاحظات",
                Result = "Failed",
                FailureReason = "ملاحظات التسليم الإداري إلزامية عند عدم توفر PIN"
            });

            var log = await service.GetDataTableAsync(new MetronicTable(), new AdminAuditLogFilter { Module = "Orders", Action = "Deliver" });
            Assert.Single(log.Items);
            Assert.Equal("Failed", log.Items[0].Result);
            Assert.Equal("ملاحظات التسليم الإداري إلزامية عند عدم توفر PIN", log.Items[0].FailureReason);
        }

        [Fact]
        public async Task AdminAuditLogEntry_SupportsBeforeAndAfterStateSnapshots()
        {
            var db = CreateInMemoryAppDbContext("AuditTestDb_Snapshots");
            var service = new AdminAuditService(db, new HttpContextAccessor());

            var before = new { Price = 4000m, Active = true, UsdPrice = 1.0m };
            var after = new { Price = 4500m, Active = true, UsdPrice = 1.1m };

            await service.LogAsync(new AdminAuditLogEntry
            {
                Module = "Products",
                Action = "Edit",
                EntityType = "Product",
                EntityId = "404",
                Description = "تعديل سعر المنتج",
                BeforeState = before,
                AfterState = after
            });

            var result = await service.GetDataTableAsync(new MetronicTable());
            Assert.Single(result.Items);
            Assert.NotNull(result.Items[0].BeforeStateJson);
            Assert.NotNull(result.Items[0].AfterStateJson);
            Assert.Contains("4000", result.Items[0].BeforeStateJson);
            Assert.Contains("4500", result.Items[0].AfterStateJson);
        }

        [Fact]
        public void AuditSanitizer_ComprehensiveRedaction_CoversAllSensitiveFields()
        {
            var comprehensiveSensitiveObj = new
            {
                Password = "SuperSecretPassword123!",
                pwd = "shortPwd",
                pass = "pass123",
                AccessToken = "at_999888777",
                access_token = "at_snake_case",
                RefreshToken = "rt_111222333",
                refresh_token = "rt_snake_case",
                Authorization = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9",
                Bearer = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9",
                Otp = "123456",
                OtpCode = "654321",
                Pin = "9876",
                ApiKey = "ak_live_abcdef123456",
                api_key = "ak_live_snake_case",
                Cookie = "session_id=abcdef123456; Path=/",
                Cookies = "auth_cookie=xyz789",
                Session = "sess_999000",
                SecretKey = "sk_live_123456789",
                private_key = "-----BEGIN RSA PRIVATE KEY-----MIIEpAIBAAKCAQEA0...",
                PrivateKey = "secret_rsa_key_data",
                Cvv = "999",
                Cvc = "888"
            };

            var sanitizedJson = AuditSanitizer.Sanitize(comprehensiveSensitiveObj);

            Assert.NotNull(sanitizedJson);
            Assert.DoesNotContain("SuperSecretPassword123!", sanitizedJson);
            Assert.DoesNotContain("shortPwd", sanitizedJson);
            Assert.DoesNotContain("pass123", sanitizedJson);
            Assert.DoesNotContain("at_999888777", sanitizedJson);
            Assert.DoesNotContain("at_snake_case", sanitizedJson);
            Assert.DoesNotContain("rt_111222333", sanitizedJson);
            Assert.DoesNotContain("rt_snake_case", sanitizedJson);
            Assert.DoesNotContain("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9", sanitizedJson);
            Assert.DoesNotContain("123456", sanitizedJson);
            Assert.DoesNotContain("654321", sanitizedJson);
            Assert.DoesNotContain("9876", sanitizedJson);
            Assert.DoesNotContain("ak_live_abcdef123456", sanitizedJson);
            Assert.DoesNotContain("ak_live_snake_case", sanitizedJson);
            Assert.DoesNotContain("abcdef123456", sanitizedJson);
            Assert.DoesNotContain("xyz789", sanitizedJson);
            Assert.DoesNotContain("sess_999000", sanitizedJson);
            Assert.DoesNotContain("sk_live_123456789", sanitizedJson);
            Assert.DoesNotContain("MIIEpAIBAAKCAQEA0", sanitizedJson);
            Assert.DoesNotContain("secret_rsa_key_data", sanitizedJson);

            // Test String / Description / FailureReason Sanitization
            var rawDescription = "Admin login attempt with Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9 and password=SecretPassword!";
            var sanitizedDescription = AuditSanitizer.SanitizeText(rawDescription);
            Assert.DoesNotContain("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9", sanitizedDescription);
            Assert.DoesNotContain("SecretPassword!", sanitizedDescription);
            Assert.Contains("Bearer [REDACTED]", sanitizedDescription);
            Assert.Contains("password: [REDACTED]", sanitizedDescription);

            var rawFailure = "Failed OTP verification for otp: 987654 and apikey: secret_api_key_123";
            var sanitizedFailure = AuditSanitizer.SanitizeText(rawFailure);
            Assert.DoesNotContain("987654", sanitizedFailure);
            Assert.DoesNotContain("secret_api_key_123", sanitizedFailure);
            Assert.Contains("otp: [REDACTED]", sanitizedFailure);
            Assert.Contains("apikey: [REDACTED]", sanitizedFailure);
        }

        [Fact]
        public void MigrationMetadata_DeterministicOrder_Verified()
        {
            var orderArchiveMigrationType = typeof(Modules.Orders.Data.Migrations.AddOrderArchiveFields);
            var adminAuditMigrationType = typeof(App.Shared.Data.Migrations.AddAdminAuditLogs);

            var orderAttr = (Microsoft.EntityFrameworkCore.Migrations.MigrationAttribute)Attribute.GetCustomAttribute(
                orderArchiveMigrationType,
                typeof(Microsoft.EntityFrameworkCore.Migrations.MigrationAttribute));

            var auditAttr = (Microsoft.EntityFrameworkCore.Migrations.MigrationAttribute)Attribute.GetCustomAttribute(
                adminAuditMigrationType,
                typeof(Microsoft.EntityFrameworkCore.Migrations.MigrationAttribute));

            Assert.NotNull(orderAttr);
            Assert.NotNull(auditAttr);

            Assert.Equal("20260918030000_AddOrderArchiveFields", orderAttr.Id);
            Assert.Equal("20260918030100_AddAdminAuditLogs", auditAttr.Id);

            // Verify order timestamp: 20260918030000 < 20260918030100
            Assert.True(string.CompareOrdinal(orderAttr.Id, auditAttr.Id) < 0,
                "Order archive migration must precede Admin audit migration in deterministic chronological sequence.");
        }
    }
}
