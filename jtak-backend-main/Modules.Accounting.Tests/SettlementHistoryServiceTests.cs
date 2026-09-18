using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using App.Catalog.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using Modules.Accounting.Services;
using CatalogMerchant = Modules.Catalog.Entities.Merchant;
using Xunit;

namespace Modules.Accounting.Tests
{
    public class SettlementHistoryServiceTests
    {
        private AccountingDbContext CreateInMemoryAccountingContext()
        {
            var options = new DbContextOptionsBuilder<AccountingDbContext>()
                .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
                .AddInterceptors(new LedgerImmutabilityInterceptor())
                .Options;
            return new AccountingDbContext(options, null);
        }

        private CatalogDbContext CreateInMemoryCatalogContext()
        {
            var options = new DbContextOptionsBuilder<CatalogDbContext>()
                .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
                .Options;
            return new CatalogDbContext(options, null);
        }

        [Fact]
        public async Task TestA_SyntheticCompletedSettlement_AppearsInHistory_AndGeneratesReceipt()
        {
            // Scenario A: Synthetic completed merchant settlement fixture
            using var accountingDb = CreateInMemoryAccountingContext();
            using var catalogDb = CreateInMemoryCatalogContext();

            var m26 = new CatalogMerchant { Id = 26, Title = "محطة اللحوم", OwnerName = "Ahmad Meat", Phone1 = "+963933111222", Active = true };
            catalogDb.Merchants.Add(m26);
            await catalogDb.SaveChangesAsync();

            var adminId = Guid.NewGuid();
            var completedId = Guid.NewGuid();

            var completedSettlement = new SettlementRequest
            {
                Id = completedId,
                RequestNumber = "SET-SYNTH-COMPLETED-0001",
                PartyType = SettlementPartyType.Merchant,
                Status = SettlementRequestStatus.Completed,
                Amount = 50000m,
                Currency = "SYP",
                Method = "Cash",
                AccountDetails = "1010-CASH-SAFE",
                CreatedDate = DateTime.UtcNow.AddHours(-2),
                ReviewedAt = DateTime.UtcNow.AddHours(-1),
                CompletedAt = DateTime.UtcNow.AddMinutes(-30),
                ReviewedByAdminId = adminId,
                CompletedByAdminId = adminId,
                Notes = "تسوية دورية للمحل (Synthetic Fixture)",
                MerchantAllocations = new List<SettlementRequestMerchantAllocation>
                {
                    new SettlementRequestMerchantAllocation { MerchantId = 26, MerchantTitle = "محطة اللحوم", Amount = 50000m }
                }
            };

            var journalEntry = new JournalTransaction
            {
                Id = Guid.NewGuid(),
                TransactionNumber = "TXN-SYNTH-SET-0001",
                ReferenceType = "SETTLEMENT",
                ReferenceId = completedId.ToString(),
                PostedDate = DateTime.UtcNow.AddMinutes(-30),
                Description = "قيد تسوية محطة اللحوم"
            };

            accountingDb.SettlementRequests.Add(completedSettlement);
            accountingDb.JournalTransactions.Add(journalEntry);
            await accountingDb.SaveChangesAsync();

            var service = new SettlementHistoryService(accountingDb, catalogDb, null, NullLogger<SettlementHistoryService>.Instance);

            // 1. Verify DataTable Query
            var dtResult = await service.GetDataTableAsync(new SettlementHistoryDataTableRequest
            {
                PartyFilter = SettlementHistoryPartyFilter.All,
                Page = 1,
                PageSize = 10
            });

            Assert.Equal(1, dtResult.TotalRecords);
            Assert.Single(dtResult.Items);
            var item = dtResult.Items[0];
            Assert.Equal("SET-SYNTH-COMPLETED-0001", item.RequestNumber);
            Assert.Equal(50000m, item.Amount);
            Assert.Equal("محطة اللحوم", item.PartyName);
            Assert.Equal(26, item.MerchantId);
            Assert.Equal("2010-VND-26", item.DestinationAccount);
            Assert.Equal("TXN-SYNTH-SET-0001", item.JournalTransactionNumber);

            // 2. Verify Summary Totals
            Assert.Equal(50000m, dtResult.Summary.TotalCompletedAmount);
            Assert.Equal(1, dtResult.Summary.TotalCompletedCount);
            Assert.Equal(50000m, dtResult.Summary.MerchantCompletedAmount);
            Assert.Equal(0m, dtResult.Summary.DriverCompletedAmount);

            // 3. Verify Receipt Generation
            var receipt = await service.GetReceiptAsync(completedId.ToString());
            Assert.NotNull(receipt);
            Assert.Equal("SET-SYNTH-COMPLETED-0001", receipt.RequestNumber);
            Assert.Equal("REC-SET-SYNTH-COMPLETED-0001", receipt.ReceiptNumber);
            Assert.Equal("محطة اللحوم", receipt.PartyName);
            Assert.Equal("+963933111222", receipt.Phone);
            Assert.Equal(50000m, receipt.Amount);
            Assert.Equal("2010-VND-26", receipt.VendorPayableAccount);
            Assert.Equal("1000 - خزينة الشركة الرئيسية", receipt.PayoutSourceAccount);
            Assert.Equal("TXN-SYNTH-SET-0001", receipt.JournalTransactionNumber);
        }

        [Fact]
        public async Task TestB_LiveEquivalent_ApprovedAwaitingReceipt_Merchant26_MustBeExcludedFromHistory_AndRejectReceipt()
        {
            // Scenario B: Live-equivalent scenario representing Merchant #26 with 1,125 SYP in Approved / Awaiting Receipt state
            using var accountingDb = CreateInMemoryAccountingContext();
            using var catalogDb = CreateInMemoryCatalogContext();

            var m26 = new CatalogMerchant { Id = 26, Title = "محطة اللحوم", OwnerName = "Ahmad Meat", Phone1 = "+963933111222", Active = true };
            catalogDb.Merchants.Add(m26);
            await catalogDb.SaveChangesAsync();

            var adminId = Guid.NewGuid();
            var approvedRequestId = Guid.NewGuid();

            // Synthetic fixture matching live status: Approved (Awaiting Merchant Receipt / Handover)
            var approvedSettlement = new SettlementRequest
            {
                Id = approvedRequestId,
                RequestNumber = "SET-SYNTH-APPROVED-M26",
                PartyType = SettlementPartyType.Merchant,
                Status = SettlementRequestStatus.Approved, // NOT Completed
                Amount = 1125m,
                Currency = "SYP",
                Method = "Cash",
                AccountDetails = "1010-CASH-SAFE",
                CreatedDate = DateTime.UtcNow.AddHours(-1),
                ReviewedAt = DateTime.UtcNow.AddMinutes(-45),
                ReviewedByAdminId = adminId,
                MerchantAllocations = new List<SettlementRequestMerchantAllocation>
                {
                    new SettlementRequestMerchantAllocation { MerchantId = 26, MerchantTitle = "محطة اللحوم", Amount = 1125m }
                }
            };

            accountingDb.SettlementRequests.Add(approvedSettlement);
            await accountingDb.SaveChangesAsync();

            var service = new SettlementHistoryService(accountingDb, catalogDb, null, NullLogger<SettlementHistoryService>.Instance);

            // 1. Must NOT appear in completed payment history
            var dtResult = await service.GetDataTableAsync(new SettlementHistoryDataTableRequest
            {
                PartyFilter = SettlementHistoryPartyFilter.All,
                Page = 1,
                PageSize = 10
            });

            Assert.Equal(0, dtResult.TotalRecords);
            Assert.Empty(dtResult.Items);
            Assert.DoesNotContain(dtResult.Items, x => x.RequestNumber == "SET-SYNTH-APPROVED-M26");
            Assert.Equal(0m, dtResult.Summary.TotalCompletedAmount);
            Assert.Equal(0, dtResult.Summary.TotalCompletedCount);

            // 2. Receipt generation MUST be strictly rejected with InvalidOperationException
            var ex = await Assert.ThrowsAsync<InvalidOperationException>(async () =>
            {
                await service.GetReceiptAsync(approvedRequestId.ToString());
            });

            Assert.Contains("لا يمكن طباعة إيصال لطلب تسوية غير مكتمل", ex.Message);
        }

        [Fact]
        public async Task PartyFilter_CorrectlyIsolates_MerchantsAndCaptains()
        {
            using var accountingDb = CreateInMemoryAccountingContext();
            using var catalogDb = CreateInMemoryCatalogContext();

            var merchantReq = new SettlementRequest
            {
                Id = Guid.NewGuid(),
                RequestNumber = "SET-SYNTH-MCH-0001",
                PartyType = SettlementPartyType.Merchant,
                Status = SettlementRequestStatus.Completed,
                Amount = 100000m,
                Currency = "SYP",
                CompletedAt = DateTime.UtcNow.AddDays(-2),
                MerchantAllocations = new List<SettlementRequestMerchantAllocation>
                {
                    new SettlementRequestMerchantAllocation { MerchantId = 15, MerchantTitle = "مطعم الشام", Amount = 100000m }
                }
            };

            var captainReq = new SettlementRequest
            {
                Id = Guid.NewGuid(),
                RequestNumber = "SET-SYNTH-CAP-0002",
                PartyType = SettlementPartyType.Captain,
                Status = SettlementRequestStatus.Completed,
                Amount = 40000m,
                Currency = "SYP",
                RequestedByUserId = Guid.NewGuid(),
                RequestedByName = "الكابتن سامر",
                CompletedAt = DateTime.UtcNow.AddDays(-1)
            };

            accountingDb.SettlementRequests.AddRange(merchantReq, captainReq);
            await accountingDb.SaveChangesAsync();

            var service = new SettlementHistoryService(accountingDb, catalogDb, null, NullLogger<SettlementHistoryService>.Instance);

            // 1. Merchant Filter
            var merchantResult = await service.GetDataTableAsync(new SettlementHistoryDataTableRequest
            {
                PartyFilter = SettlementHistoryPartyFilter.Merchant
            });
            Assert.Single(merchantResult.Items);
            Assert.Equal("SET-SYNTH-MCH-0001", merchantResult.Items[0].RequestNumber);
            Assert.Equal(100000m, merchantResult.Summary.TotalCompletedAmount);

            // 2. Captain Filter
            var captainResult = await service.GetDataTableAsync(new SettlementHistoryDataTableRequest
            {
                PartyFilter = SettlementHistoryPartyFilter.Captain
            });
            Assert.Single(captainResult.Items);
            Assert.Equal("SET-SYNTH-CAP-0002", captainResult.Items[0].RequestNumber);
            Assert.Equal(40000m, captainResult.Summary.TotalCompletedAmount);
        }

        [Fact]
        public async Task SearchTerm_Matches_RequestNumber_PartyName_And_JournalTxn()
        {
            using var accountingDb = CreateInMemoryAccountingContext();
            using var catalogDb = CreateInMemoryCatalogContext();

            var req1Id = Guid.NewGuid();
            var req1 = new SettlementRequest
            {
                Id = req1Id,
                RequestNumber = "SET-SYNTH-SEARCH-0001",
                PartyType = SettlementPartyType.Merchant,
                Status = SettlementRequestStatus.Completed,
                Amount = 50000m,
                Currency = "SYP",
                CompletedAt = DateTime.UtcNow,
                MerchantAllocations = new List<SettlementRequestMerchantAllocation>
                {
                    new SettlementRequestMerchantAllocation { MerchantId = 26, MerchantTitle = "محطة اللحوم", Amount = 50000m }
                }
            };

            var req2 = new SettlementRequest
            {
                Id = Guid.NewGuid(),
                RequestNumber = "SET-SYNTH-SEARCH-0002",
                PartyType = SettlementPartyType.Merchant,
                Status = SettlementRequestStatus.Completed,
                Amount = 25000m,
                Currency = "SYP",
                CompletedAt = DateTime.UtcNow,
                MerchantAllocations = new List<SettlementRequestMerchantAllocation>
                {
                    new SettlementRequestMerchantAllocation { MerchantId = 10, MerchantTitle = "سوبرماركت البركة", Amount = 25000m }
                }
            };

            var journalEntry = new JournalTransaction
            {
                Id = Guid.NewGuid(),
                TransactionNumber = "TXN-SYNTH-SEARCH-0001",
                ReferenceType = "SETTLEMENT",
                ReferenceId = req1Id.ToString(),
                PostedDate = DateTime.UtcNow,
                Description = "تسوية محطة اللحوم"
            };

            accountingDb.SettlementRequests.AddRange(req1, req2);
            accountingDb.JournalTransactions.Add(journalEntry);
            await accountingDb.SaveChangesAsync();

            var service = new SettlementHistoryService(accountingDb, catalogDb, null, NullLogger<SettlementHistoryService>.Instance);

            // Search by Request Number
            var search1 = await service.GetDataTableAsync(new SettlementHistoryDataTableRequest { SearchTerm = "SEARCH-0001" });
            Assert.Single(search1.Items);
            Assert.Equal("SET-SYNTH-SEARCH-0001", search1.Items[0].RequestNumber);

            // Search by Merchant Title in Arabic
            var search2 = await service.GetDataTableAsync(new SettlementHistoryDataTableRequest { SearchTerm = "البركة" });
            Assert.Single(search2.Items);
            Assert.Equal("SET-SYNTH-SEARCH-0002", search2.Items[0].RequestNumber);

            // Search by Journal Transaction Number
            var search3 = await service.GetDataTableAsync(new SettlementHistoryDataTableRequest { SearchTerm = "TXN-SYNTH-SEARCH-0001" });
            Assert.Single(search3.Items);
            Assert.Equal("SET-SYNTH-SEARCH-0001", search3.Items[0].RequestNumber);
            Assert.Equal("TXN-SYNTH-SEARCH-0001", search3.Items[0].JournalTransactionNumber);
        }

        [Fact]
        public async Task ReadOnlyGuarantees_QueryDoesNotMutateDatabase_OrAddExtraJournals()
        {
            using var accountingDb = CreateInMemoryAccountingContext();
            using var catalogDb = CreateInMemoryCatalogContext();

            var completedReq = new SettlementRequest
            {
                Id = Guid.NewGuid(),
                RequestNumber = "SET-SYNTH-READONLY-0001",
                PartyType = SettlementPartyType.Merchant,
                Status = SettlementRequestStatus.Completed,
                Amount = 80000m,
                Currency = "SYP",
                CompletedAt = DateTime.UtcNow,
                MerchantAllocations = new List<SettlementRequestMerchantAllocation>
                {
                    new SettlementRequestMerchantAllocation { MerchantId = 5, MerchantTitle = "محل الورد", Amount = 80000m }
                }
            };

            accountingDb.SettlementRequests.Add(completedReq);
            await accountingDb.SaveChangesAsync();

            var initialSettlementCount = await accountingDb.SettlementRequests.CountAsync();
            var initialJournalCount = await accountingDb.JournalTransactions.CountAsync();

            var service = new SettlementHistoryService(accountingDb, catalogDb, null, NullLogger<SettlementHistoryService>.Instance);

            // Execute reads
            var dt = await service.GetDataTableAsync(new SettlementHistoryDataTableRequest());
            var summary = await service.GetSummaryAsync();
            var receipt = await service.GetReceiptAsync(completedReq.Id.ToString());
            var printData = await service.GetPrintDataAsync(new SettlementHistoryDataTableRequest());

            // Assert absolute database immutability
            Assert.Equal(initialSettlementCount, await accountingDb.SettlementRequests.CountAsync());
            Assert.Equal(initialJournalCount, await accountingDb.JournalTransactions.CountAsync());
        }
    }
}
