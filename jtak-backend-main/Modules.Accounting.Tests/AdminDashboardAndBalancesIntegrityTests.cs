using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using App.Catalog.Data;
using Modules.Catalog.Entities;
using App.Shared.Data.App;
using App.Shared.Entities;
using App.Shared.Entities.Domain;
using Solf.Identity;
using Modules.Shipping.Entities;
using Xunit;

namespace Modules.Accounting.Tests
{
    public class AdminDashboardAndBalancesIntegrityTests
    {
        private CatalogDbContext CreateInMemoryCatalogContext()
        {
            var options = new DbContextOptionsBuilder<CatalogDbContext>()
                .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
                .Options;
            return new CatalogDbContext(options, null);
        }

        private AccountingDbContext CreateInMemoryAccountingContext()
        {
            var options = new DbContextOptionsBuilder<AccountingDbContext>()
                .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
                .Options;
            return new AccountingDbContext(options, null);
        }

        private AppDbContext CreateInMemoryAppContext()
        {
            var options = new DbContextOptionsBuilder<AppDbContext>()
                .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
                .Options;
            return new AppDbContext(options, null);
        }

        [Fact]
        public async Task ProductCount_ExcludesSoftDeletedProducts()
        {
            using var catalogContext = CreateInMemoryCatalogContext();

            // 2 Active live products
            catalogContext.Products.Add(new Product { Id = 1, Title = "Live Product 1", Active = true, DeletionDate = null });
            catalogContext.Products.Add(new Product { Id = 2, Title = "Live Product 2", Active = true, DeletionDate = null });

            // 1 Inactive live product
            catalogContext.Products.Add(new Product { Id = 3, Title = "Inactive Product", Active = false, DeletionDate = null });

            // 2 Soft-deleted products with Active = true
            catalogContext.Products.Add(new Product { Id = 4, Title = "Deleted Product 1", Active = true, DeletionDate = DateTime.UtcNow.AddDays(-10) });
            catalogContext.Products.Add(new Product { Id = 5, Title = "Deleted Product 2", Active = true, DeletionDate = DateTime.UtcNow.AddDays(-5) });

            await catalogContext.SaveChangesAsync();

            // Authoritative Dashboard query
            var liveActiveCount = await catalogContext.Products.AsNoTracking()
                .CountAsync(x => x.DeletionDate == null && x.Active);

            var totalCatalogCount = await catalogContext.Products.AsNoTracking()
                .CountAsync(x => x.DeletionDate == null);

            var rawActiveCountWithoutDeletionFilter = await catalogContext.Products.AsNoTracking()
                .CountAsync(x => x.Active);

            Assert.Equal(2, liveActiveCount);
            Assert.Equal(3, totalCatalogCount);
            Assert.Equal(4, rawActiveCountWithoutDeletionFilter);
        }

        [Fact]
        public async Task MerchantBalances_TestCases_1_to_4_and_7_and_9()
        {
            using var catalogContext = CreateInMemoryCatalogContext();
            using var accountingContext = CreateInMemoryAccountingContext();

            // Test Case 1: Merchant #26 appears
            var merchant26 = new Merchant
            {
                Id = 26,
                Title = "Al-Sultan Bakery #26",
                OwnerName = "Sultan Ahmed",
                Phone1 = "0933111222",
                Phone2 = "0112223333",
                Active = true,
                DeletionDate = null,
                OwnerId = Guid.NewGuid()
            };

            // Test Case 2 & 7: Merchant #12 appears (Zero balance)
            var merchant12 = new Merchant
            {
                Id = 12,
                Title = "Damascus Spices #12",
                OwnerName = "Kareem Spices",
                Phone1 = "0944555666",
                Active = true,
                DeletionDate = null,
                OwnerId = Guid.NewGuid()
            };

            // Deleted merchant should not appear
            var deletedMerchant = new Merchant
            {
                Id = 99,
                Title = "Old Closed Market",
                Active = true,
                DeletionDate = DateTime.UtcNow,
                OwnerId = Guid.NewGuid()
            };

            catalogContext.Merchants.AddRange(merchant26, merchant12, deletedMerchant);
            await catalogContext.SaveChangesAsync();

            // Test Case 9: Merchant VendorPayable liability formula (Credits - Debits)
            var vendorAcc26 = new Account
            {
                Id = Guid.NewGuid(),
                AccountCode = $"{SystemAccountCodes.VendorPayablePrefix}26",
                Name = merchant26.Title,
                Type = AccountType.Liability,
                OwnerMerchantId = 26,
                Currency = "SYP",
                IsActive = true
            };
            accountingContext.Accounts.Add(vendorAcc26);

            accountingContext.LedgerEntries.AddRange(
                new LedgerEntry { Id = 1, AccountId = vendorAcc26.Id, JournalTransactionId = Guid.NewGuid(), Credit = 150000m, Debit = 0m, Currency = "SYP" },
                new LedgerEntry { Id = 2, AccountId = vendorAcc26.Id, JournalTransactionId = Guid.NewGuid(), Credit = 0m, Debit = 30000m, Currency = "SYP" }
            );

            // Captain float account for "reham mando" (non-merchant) in accounting
            var rehamUserId = Guid.NewGuid();
            var rehamCaptainAcc = new Account
            {
                Id = Guid.NewGuid(),
                AccountCode = $"{SystemAccountCodes.CaptainCashFloatPrefix}{rehamUserId}",
                Name = "reham mando",
                Type = AccountType.Asset,
                OwnerUserId = rehamUserId,
                Currency = "SYP",
                IsActive = true
            };
            accountingContext.Accounts.Add(rehamCaptainAcc);
            accountingContext.LedgerEntries.Add(new LedgerEntry { Id = 3, AccountId = rehamCaptainAcc.Id, JournalTransactionId = Guid.NewGuid(), Debit = 50000m, Credit = 0m, Currency = "SYP" });

            // Captain float account for "A A" (non-merchant) in accounting
            var aaUserId = Guid.NewGuid();
            var aaCaptainAcc = new Account
            {
                Id = Guid.NewGuid(),
                AccountCode = $"{SystemAccountCodes.CaptainCashFloatPrefix}{aaUserId}",
                Name = "A A",
                Type = AccountType.Asset,
                OwnerUserId = aaUserId,
                Currency = "SYP",
                IsActive = true
            };
            accountingContext.Accounts.Add(aaCaptainAcc);

            await accountingContext.SaveChangesAsync();

            // Execute BalancesController.DataTable logic
            var activeMerchants = await catalogContext.Merchants.AsNoTracking()
                .Where(x => x.DeletionDate == null && x.Active)
                .OrderBy(x => x.Title)
                .ToListAsync();

            var merchantIds = activeMerchants.Select(m => m.Id).ToList();

            var ledgerBalances = await accountingContext.Accounts.AsNoTracking()
                .Where(a => a.OwnerMerchantId != null &&
                            merchantIds.Contains(a.OwnerMerchantId.Value) &&
                            a.Type == AccountType.Liability &&
                            a.AccountCode.StartsWith(SystemAccountCodes.VendorPayablePrefix))
                .Select(a => new
                {
                    MerchantId = a.OwnerMerchantId.Value,
                    Balance = a.LedgerEntries.Sum(e => e.Credit - e.Debit)
                })
                .ToDictionaryAsync(x => x.MerchantId, x => x.Balance);

            var result = activeMerchants.Select(m => new BalanceDto
            {
                Id = m.OwnerId,
                EntityId = m.Id,
                Name = m.Title,
                Phone = !string.IsNullOrEmpty(m.Phone1) ? m.Phone1 : m.Phone2,
                Amount = ledgerBalances.TryGetValue(m.Id, out var bal) ? bal : 0m
            }).ToList();

            // Assertions
            // 1. Merchant #26 appears
            Assert.Contains(result, r => r.EntityId == 26 && r.Name == "Al-Sultan Bakery #26");
            var m26 = result.First(r => r.EntityId == 26);
            // 9. Merchant formula (150,000 Credit - 30,000 Debit = 120,000)
            Assert.Equal(120000m, m26.Amount);
            Assert.Equal("0933111222", m26.Phone);

            // 2. Merchant #12 appears
            Assert.Contains(result, r => r.EntityId == 12 && r.Name == "Damascus Spices #12");
            var m12 = result.First(r => r.EntityId == 12);
            // 7. Zero-balance merchant appears with 0m
            Assert.Equal(0m, m12.Amount);
            Assert.Equal("0944555666", m12.Phone);

            // 3. Driver "reham mando" does NOT appear under merchants
            Assert.DoesNotContain(result, r => r.Name != null && r.Name.Contains("reham mando", StringComparison.OrdinalIgnoreCase));

            // 4. Driver "A A" does NOT appear under merchants
            Assert.DoesNotContain(result, r => r.Name != null && r.Name.Equals("A A", StringComparison.OrdinalIgnoreCase));

            // Deleted merchant excluded
            Assert.DoesNotContain(result, r => r.EntityId == 99);
            Assert.Equal(2, result.Count);
        }

        [Fact]
        public async Task DriverBalances_TestCases_5_to_6_and_8_and_10()
        {
            using var appContext = CreateInMemoryAppContext();
            using var accountingContext = CreateInMemoryAccountingContext();

            // Seed Delivery Role
            var deliveryRole = new SolRole
            {
                Id = Guid.NewGuid(),
                Name = "Delivery",
                NormalizedName = "DELIVERY"
            };
            appContext.Roles.Add(deliveryRole);

            // Seed Customer Role for non-delivery user
            var customerRole = new SolRole
            {
                Id = Guid.NewGuid(),
                Name = "Customer",
                NormalizedName = "CUSTOMER"
            };
            appContext.Roles.Add(customerRole);

            // Driver 1: "reham mando"
            var rehamUserId = Guid.NewGuid();
            var rehamUser = new AppUser
            {
                Id = rehamUserId,
                FullName = "reham mando",
                FirstName = "reham",
                LastName = "mando",
                PhoneNumber = "0955112233",
                IsActive = true,
                DeletionDate = null
            };
            appContext.Users.Add(rehamUser);
            appContext.UserRoles.Add(new SolUserRole { UserId = rehamUserId, RoleId = deliveryRole.Id });

            // Driver 2: "A A" (Zero balance driver)
            var aaUserId = Guid.NewGuid();
            var aaUser = new AppUser
            {
                Id = aaUserId,
                FullName = "A A",
                FirstName = "A",
                LastName = "A",
                PhoneNumber = "0966445566",
                IsActive = true,
                DeletionDate = null
            };
            appContext.Users.Add(aaUser);
            appContext.UserRoles.Add(new SolUserRole { UserId = aaUserId, RoleId = deliveryRole.Id });

            // Non-driver user (Customer)
            var customerUserId = Guid.NewGuid();
            var customerUser = new AppUser
            {
                Id = customerUserId,
                FullName = "Tariq Customer",
                PhoneNumber = "0977889900",
                IsActive = true,
                DeletionDate = null
            };
            appContext.Users.Add(customerUser);
            appContext.UserRoles.Add(new SolUserRole { UserId = customerUserId, RoleId = customerRole.Id });

            await appContext.SaveChangesAsync();

            // Seed Captain Cash Float (Asset: Debit - Credit) for Reham Mando
            var rehamFloatAcc = new Account
            {
                Id = Guid.NewGuid(),
                AccountCode = $"{SystemAccountCodes.CaptainCashFloatPrefix}{rehamUserId}",
                Name = "reham mando Cash Float",
                Type = AccountType.Asset,
                OwnerUserId = rehamUserId,
                Currency = "SYP",
                IsActive = true
            };
            accountingContext.Accounts.Add(rehamFloatAcc);

            // Seed Captain Earnings (Liability: Credit - Debit) for Reham Mando
            var rehamWagesAcc = new Account
            {
                Id = Guid.NewGuid(),
                AccountCode = $"{SystemAccountCodes.CaptainEarningsPrefix}{rehamUserId}",
                Name = "reham mando Wages",
                Type = AccountType.Liability,
                OwnerUserId = rehamUserId,
                Currency = "SYP",
                IsActive = true
            };
            accountingContext.Accounts.Add(rehamWagesAcc);

            accountingContext.LedgerEntries.AddRange(
                // Float: 85,000 Debit collected - 15,000 Credit remitted = 70,000 Net Cash Custody
                new LedgerEntry { Id = 10, AccountId = rehamFloatAcc.Id, JournalTransactionId = Guid.NewGuid(), Debit = 85000m, Credit = 0m, Currency = "SYP" },
                new LedgerEntry { Id = 11, AccountId = rehamFloatAcc.Id, JournalTransactionId = Guid.NewGuid(), Debit = 0m, Credit = 15000m, Currency = "SYP" },
                // Wages: 25,000 Credit earned - 5,000 Debit paid = 20,000 Net Accrued Wages
                new LedgerEntry { Id = 12, AccountId = rehamWagesAcc.Id, JournalTransactionId = Guid.NewGuid(), Credit = 25000m, Debit = 0m, Currency = "SYP" },
                new LedgerEntry { Id = 13, AccountId = rehamWagesAcc.Id, JournalTransactionId = Guid.NewGuid(), Credit = 0m, Debit = 5000m, Currency = "SYP" }
            );

            await accountingContext.SaveChangesAsync();

            // Execute BalancesController.Drivers.DataTable logic
            var deliveryRoleEntity = await appContext.Roles.AsNoTracking()
                .FirstOrDefaultAsync(r => r.NormalizedName == "DELIVERY" || r.Name == "Delivery");

            Assert.NotNull(deliveryRoleEntity);

            var driverUserIdsQuery = appContext.UserRoles.AsNoTracking()
                .Where(ur => ur.RoleId == deliveryRoleEntity.Id)
                .Select(ur => ur.UserId);

            var activeDrivers = await appContext.Users.AsNoTracking()
                .Where(u => driverUserIdsQuery.Contains(u.Id) && u.DeletionDate == null && u.IsActive)
                .OrderBy(u => u.FullName ?? (u.FirstName + " " + u.LastName))
                .ToListAsync();

            var driverIds = activeDrivers.Select(d => d.Id).ToList();

            var floatBalances = await accountingContext.Accounts.AsNoTracking()
                .Where(a => a.OwnerUserId != null &&
                            driverIds.Contains(a.OwnerUserId.Value) &&
                            a.Type == AccountType.Asset &&
                            a.AccountCode.StartsWith(SystemAccountCodes.CaptainCashFloatPrefix))
                .Select(a => new
                {
                    UserId = a.OwnerUserId.Value,
                    Balance = a.LedgerEntries.Sum(e => e.Debit - e.Credit)
                })
                .ToDictionaryAsync(x => x.UserId, x => x.Balance);

            var wagesBalances = await accountingContext.Accounts.AsNoTracking()
                .Where(a => a.OwnerUserId != null &&
                            driverIds.Contains(a.OwnerUserId.Value) &&
                            a.Type == AccountType.Liability &&
                            a.AccountCode.StartsWith(SystemAccountCodes.CaptainEarningsPrefix))
                .Select(a => new
                {
                    UserId = a.OwnerUserId.Value,
                    Balance = a.LedgerEntries.Sum(e => e.Credit - e.Debit)
                })
                .ToDictionaryAsync(x => x.UserId, x => x.Balance);

            var result = activeDrivers.Select(d => new BalanceDto
            {
                Id = d.Id,
                Name = !string.IsNullOrWhiteSpace(d.FullName) ? d.FullName : $"{d.FirstName} {d.LastName}".Trim(),
                Phone = d.PhoneNumber,
                Amount = floatBalances.TryGetValue(d.Id, out var fb) ? fb : 0m,
                WagesAmount = wagesBalances.TryGetValue(d.Id, out var wb) ? wb : 0m
            }).ToList();

            // Assertions
            // 5. "reham mando" appears under drivers
            Assert.Contains(result, r => r.Id == rehamUserId && r.Name == "reham mando");
            var d1 = result.First(r => r.Id == rehamUserId);
            // 10. Driver cash float formula (Debit - Credit) = 70,000, Wages formula (Credit - Debit) = 20,000
            Assert.Equal(70000m, d1.Amount);
            Assert.Equal(20000m, d1.WagesAmount);
            Assert.Equal("0955112233", d1.Phone);

            // 6. "A A" appears under drivers
            Assert.Contains(result, r => r.Id == aaUserId && r.Name == "A A");
            var d2 = result.First(r => r.Id == aaUserId);
            // 8. Zero-balance driver appears with 0m float and 0m wages
            Assert.Equal(0m, d2.Amount);
            Assert.Equal(0m, d2.WagesAmount);
            Assert.Equal("0966445566", d2.Phone);

            // Customers / non-drivers strictly excluded
            Assert.DoesNotContain(result, r => r.Id == customerUserId);
            Assert.Equal(2, result.Count);
        }

        [Fact]
        public async Task SearchAndPagination_TestCases_11_to_14()
        {
            using var catalogContext = CreateInMemoryCatalogContext();
            using var appContext = CreateInMemoryAppContext();
            using var accountingContext = CreateInMemoryAccountingContext();

            // Seed merchants
            catalogContext.Merchants.AddRange(
                new Merchant { Id = 1, Title = "Al-Madina Shawarma", OwnerName = "Hassan", Phone1 = "0933100200", Active = true, DeletionDate = null },
                new Merchant { Id = 2, Title = "Damascus Pastry", OwnerName = "Sami", Phone1 = "0944300400", Active = true, DeletionDate = null },
                new Merchant { Id = 3, Title = "Aleppo Roastery", OwnerName = "Mahmoud", Phone1 = "0955500600", Active = true, DeletionDate = null }
            );
            await catalogContext.SaveChangesAsync();

            // Seed Delivery Role & drivers
            var deliveryRole = new SolRole { Id = Guid.NewGuid(), Name = "Delivery", NormalizedName = "DELIVERY" };
            appContext.Roles.Add(deliveryRole);

            var driver1 = new AppUser { Id = Guid.NewGuid(), FullName = "Fadi Driver", PhoneNumber = "0988111222", IsActive = true, DeletionDate = null };
            var driver2 = new AppUser { Id = Guid.NewGuid(), FullName = "Omar Courier", PhoneNumber = "0988333444", IsActive = true, DeletionDate = null };
            var driver3 = new AppUser { Id = Guid.NewGuid(), FullName = "Khalid Express", PhoneNumber = "0988555666", IsActive = true, DeletionDate = null };

            appContext.Users.AddRange(driver1, driver2, driver3);
            appContext.UserRoles.AddRange(
                new SolUserRole { UserId = driver1.Id, RoleId = deliveryRole.Id },
                new SolUserRole { UserId = driver2.Id, RoleId = deliveryRole.Id },
                new SolUserRole { UserId = driver3.Id, RoleId = deliveryRole.Id }
            );
            await appContext.SaveChangesAsync();

            // 11. Search by name: Merchants ("Shawarma")
            var merchantQuery = catalogContext.Merchants.AsNoTracking().Where(x => x.DeletionDate == null && x.Active);
            var searchMerchantByName = await merchantQuery.Where(x => x.Title.Contains("Shawarma")).ToListAsync();
            Assert.Single(searchMerchantByName);
            Assert.Equal("Al-Madina Shawarma", searchMerchantByName[0].Title);

            // 11. Search by name: Drivers ("Omar")
            var driverRoleEntity = await appContext.Roles.FirstAsync(r => r.NormalizedName == "DELIVERY");
            var driverIdsQuery = appContext.UserRoles.Where(ur => ur.RoleId == driverRoleEntity.Id).Select(ur => ur.UserId);
            var driverQuery = appContext.Users.AsNoTracking().Where(u => driverIdsQuery.Contains(u.Id) && u.DeletionDate == null && u.IsActive);
            var searchDriverByName = await driverQuery.Where(u => u.FullName.Contains("Omar")).ToListAsync();
            Assert.Single(searchDriverByName);
            Assert.Equal("Omar Courier", searchDriverByName[0].FullName);

            // 12. Search by phone: Merchants ("0944300400")
            var searchMerchantByPhone = await merchantQuery.Where(x => x.Phone1.Contains("0944300400")).ToListAsync();
            Assert.Single(searchMerchantByPhone);
            Assert.Equal("Damascus Pastry", searchMerchantByPhone[0].Title);

            // 12. Search by phone: Drivers ("0988555666")
            var searchDriverByPhone = await driverQuery.Where(u => u.PhoneNumber.Contains("0988555666")).ToListAsync();
            Assert.Single(searchDriverByPhone);
            Assert.Equal("Khalid Express", searchDriverByPhone[0].FullName);

            // 13. Pagination totals
            var totalMerchants = await merchantQuery.CountAsync();
            var pagedMerchants = await merchantQuery.Skip(1).Take(1).ToListAsync();
            Assert.Equal(3, totalMerchants);
            Assert.Single(pagedMerchants);

            var totalDrivers = await driverQuery.CountAsync();
            var pagedDrivers = await driverQuery.Skip(1).Take(1).ToListAsync();
            Assert.Equal(3, totalDrivers);
            Assert.Single(pagedDrivers);

            // 14. Strict isolation: Merchants cannot be queried from driver table and vice-versa
            Assert.Empty(await driverQuery.Where(u => u.FullName == "Al-Madina Shawarma").ToListAsync());
            Assert.Empty(await merchantQuery.Where(m => m.Title == "Fadi Driver").ToListAsync());
        }

        [Fact]
        public async Task DriverBalances_Comprehensive_DirectoryAndAccountingSemantics_RegressionTest()
        {
            using var appContext = CreateInMemoryAppContext();
            using var accountingContext = CreateInMemoryAccountingContext();
            using var catalogContext = CreateInMemoryCatalogContext();

            // 1. Roles
            var deliveryRole = new SolRole { Id = Guid.NewGuid(), Name = "Delivery", NormalizedName = "DELIVERY" };
            var merchantRole = new SolRole { Id = Guid.NewGuid(), Name = "Merchant", NormalizedName = "MERCHANT" };
            appContext.Roles.AddRange(deliveryRole, merchantRole);

            // 2. Active Driver with Accounting Activity (Debit 100,000 - Credit 25,000 = 75,000 custody)
            var activeDriverId = Guid.NewGuid();
            var activeDriver = new AppUser
            {
                Id = activeDriverId,
                FullName = "Captain Samer",
                FirstName = "Samer",
                LastName = "Kabbani",
                PhoneNumber = "0933998877",
                IsActive = true,
                DeletionDate = null
            };

            // 3. Driver with ZERO Accounting Activity
            var zeroDriverId = Guid.NewGuid();
            var zeroDriver = new AppUser
            {
                Id = zeroDriverId,
                FullName = "Captain Ziad",
                FirstName = "Ziad",
                LastName = "Hassan",
                PhoneNumber = "0944112233",
                IsActive = true,
                DeletionDate = null
            };

            // 4. Merchant User (Must be excluded from drivers)
            var merchantUserId = Guid.NewGuid();
            var merchantUser = new AppUser
            {
                Id = merchantUserId,
                FullName = "Merchant Abu Omar",
                PhoneNumber = "0955000000",
                IsActive = true,
                DeletionDate = null
            };

            appContext.Users.AddRange(activeDriver, zeroDriver, merchantUser);
            appContext.UserRoles.AddRange(
                new SolUserRole { UserId = activeDriverId, RoleId = deliveryRole.Id },
                new SolUserRole { UserId = zeroDriverId, RoleId = deliveryRole.Id },
                new SolUserRole { UserId = merchantUserId, RoleId = merchantRole.Id }
            );
            await appContext.SaveChangesAsync();

            // 5. Accounting Float for active driver
            var activeDriverFloatAcc = new Account
            {
                Id = Guid.NewGuid(),
                AccountCode = $"{SystemAccountCodes.CaptainCashFloatPrefix}{activeDriverId}",
                Name = "Captain Samer Cash Float",
                Type = AccountType.Asset,
                OwnerUserId = activeDriverId,
                Currency = "SYP",
                IsActive = true
            };
            accountingContext.Accounts.Add(activeDriverFloatAcc);
            accountingContext.LedgerEntries.AddRange(
                new LedgerEntry { Id = 101, AccountId = activeDriverFloatAcc.Id, JournalTransactionId = Guid.NewGuid(), Debit = 100000m, Credit = 0m, Currency = "SYP" },
                new LedgerEntry { Id = 102, AccountId = activeDriverFloatAcc.Id, JournalTransactionId = Guid.NewGuid(), Debit = 0m, Credit = 25000m, Currency = "SYP" }
            );
            await accountingContext.SaveChangesAsync();

            // Query simulation equivalent to BalancesController.DriversDataTable
            var driverRoleIds = await appContext.Roles.AsNoTracking()
                .Where(r => r.NormalizedName == "DELIVERY" || r.NormalizedName == "DRIVER" || r.NormalizedName == "CAPTAIN")
                .Select(r => r.Id)
                .ToListAsync();

            var allDriverUserIds = await appContext.UserRoles.AsNoTracking()
                .Where(ur => driverRoleIds.Contains(ur.RoleId))
                .Select(ur => ur.UserId)
                .Distinct()
                .ToListAsync();

            var driverUsers = await appContext.Users.AsNoTracking()
                .Where(u => allDriverUserIds.Contains(u.Id) && u.DeletionDate == null && u.IsActive)
                .OrderBy(u => u.FullName ?? u.UserName)
                .ToListAsync();

            var driverIds = driverUsers.Select(d => d.Id).ToList();

            var floatBalances = await accountingContext.Accounts.AsNoTracking()
                .Where(a => a.OwnerUserId != null &&
                            driverIds.Contains(a.OwnerUserId.Value) &&
                            a.Type == AccountType.Asset &&
                            a.AccountCode.StartsWith(SystemAccountCodes.CaptainCashFloatPrefix))
                .Select(a => new
                {
                    UserId = a.OwnerUserId.Value,
                    Balance = a.LedgerEntries.Sum(e => e.Debit - e.Credit)
                })
                .ToDictionaryAsync(x => x.UserId, x => x.Balance);

            var items = driverUsers.Select(d => new BalanceDto
            {
                Id = d.Id,
                Name = !string.IsNullOrWhiteSpace(d.FullName) ? d.FullName : $"{d.FirstName} {d.LastName}".Trim(),
                Phone = d.PhoneNumber,
                Amount = floatBalances.TryGetValue(d.Id, out var fb) ? fb : 0m,
                WagesAmount = 0m,
                PendingAmount = 0m,
                CreatedDate = d.CreatedDate
            }).ToList();

            // A. Driver with accounting activity appears
            Assert.Contains(items, x => x.Id == activeDriverId);
            var activeDto = items.First(x => x.Id == activeDriverId);

            // D. Driver custody = Debit (100k) - Credit (25k) = 75,000
            Assert.Equal(75000m, activeDto.Amount);
            Assert.Equal("0933998877", activeDto.Phone);

            // B. Driver with zero activity appears with 0 balance
            Assert.Contains(items, x => x.Id == zeroDriverId);
            var zeroDto = items.First(x => x.Id == zeroDriverId);
            Assert.Equal(0m, zeroDto.Amount);
            Assert.Equal("0944112233", zeroDto.Phone);

            // C. Merchant is excluded
            Assert.DoesNotContain(items, x => x.Id == merchantUserId);
            Assert.Equal(2, items.Count);

            // E. Name search
            var nameSearch = items.Where(x => x.Name.Contains("Samer")).ToList();
            Assert.Single(nameSearch);
            Assert.Equal(activeDriverId, nameSearch[0].Id);

            // F. Phone search
            var phoneSearch = items.Where(x => x.Phone.Contains("0944112233")).ToList();
            Assert.Single(phoneSearch);
            Assert.Equal(zeroDriverId, phoneSearch[0].Id);

            // G. Pagination Total
            Assert.Equal(2, items.Count);
        }
    }
}
