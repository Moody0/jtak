using App.Catalog.Data;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Modules.Catalog.Entities;
using Modules.Catalog.Services;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Xunit;

namespace Modules.Accounting.Tests
{
    public class InventoryBatchServiceTests
    {
        private (CatalogDbContext context, ICatalogUnitOfWork uow, InventoryBatchService service) CreateTestContext()
        {
            var dbName = Guid.NewGuid().ToString();
            var options = new DbContextOptionsBuilder<CatalogDbContext>()
                .UseInMemoryDatabase(databaseName: dbName)
                .Options;

            var httpContextAccessor = new HttpContextAccessor();
            var context = new CatalogDbContext(options, httpContextAccessor);
            var uow = new CatalogUnitOfWork(context);
            var service = new InventoryBatchService(context, uow);

            return (context, uow, service);
        }

        [Fact]
        public async Task CreateBatchAsync_CreatesActiveBatchWithCorrectFields()
        {
            var (context, uow, service) = CreateTestContext();

            var dto = new CreateProductBatchDto
            {
                ProductId = 101,
                MerchantId = 5,
                BatchNumber = "BAT-2026-001",
                LotNumber = "LOT-9988",
                Barcode = "629104150001",
                Sku = "SKU-MILK-1L",
                LocationBin = "Aisle-2, Shelf-B, Bin-04",
                ExpirationDate = DateTime.UtcNow.AddMonths(3),
                InitialQuantity = 50,
                CostPrice = 2.50m,
                SellingPrice = 3.99m
            };

            var result = await service.CreateBatchAsync(dto, "TestAdmin");

            Assert.NotNull(result);
            Assert.True(result.Id > 0);
            Assert.Equal("BAT-2026-001", result.BatchNumber);
            Assert.Equal("629104150001", result.Barcode);
            Assert.Equal(50, result.QuantityOnHand);
            Assert.Equal(0, result.QuantityReserved);
            Assert.Equal(50, result.QuantityAvailable);
            Assert.Equal(BatchStatus.Active, result.Status);
        }

        [Fact]
        public async Task ReserveStockFEFOAsync_AllocatesEarliestExpiringBatchesFirst()
        {
            var (context, uow, service) = CreateTestContext();

            // Batch 1: Expires in 10 days, 5 units
            var b1 = new ProductBatch
            {
                ProductId = 200,
                MerchantId = 1,
                BatchNumber = "BAT-EARLY-10D",
                Barcode = "BC-10D",
                ExpirationDate = DateTime.UtcNow.AddDays(10),
                QuantityOnHand = 5,
                QuantityReserved = 0,
                Status = BatchStatus.Active,
                LocationBin = "Bin-1"
            };
            // Batch 2: Expires in 4 days, 3 units (earliest fresh)
            var b2 = new ProductBatch
            {
                ProductId = 200,
                MerchantId = 1,
                BatchNumber = "BAT-EARLIEST-4D",
                Barcode = "BC-4D",
                ExpirationDate = DateTime.UtcNow.AddDays(4),
                QuantityOnHand = 3,
                QuantityReserved = 0,
                Status = BatchStatus.Active,
                LocationBin = "Bin-2"
            };
            // Batch 3: Expires in 30 days, 20 units (latest)
            var b3 = new ProductBatch
            {
                ProductId = 200,
                MerchantId = 1,
                BatchNumber = "BAT-LATEST-30D",
                Barcode = "BC-30D",
                ExpirationDate = DateTime.UtcNow.AddDays(30),
                QuantityOnHand = 20,
                QuantityReserved = 0,
                Status = BatchStatus.Active,
                LocationBin = "Bin-3"
            };

            await context.ProductBatches.AddRangeAsync(b1, b2, b3);
            await uow.SaveChangesAsync();

            // Request 6 units: Should take 3 units from b2 (expires in 4d), and 3 units from b1 (expires in 10d)
            var reservations = await service.ReserveStockFEFOAsync(
                orderId: 1001,
                orderDetailId: 5001,
                productId: 200,
                merchantId: 1,
                quantity: 6,
                minDaysToExpiry: 1);

            Assert.Equal(2, reservations.Count);
            Assert.Equal("BAT-EARLIEST-4D", reservations[0].BatchNumber);
            Assert.Equal(3, reservations[0].Quantity);

            Assert.Equal("BAT-EARLY-10D", reservations[1].BatchNumber);
            Assert.Equal(3, reservations[1].Quantity);

            // Verify database state
            var freshB2 = await context.ProductBatches.FindAsync(b2.Id);
            var freshB1 = await context.ProductBatches.FindAsync(b1.Id);
            var freshB3 = await context.ProductBatches.FindAsync(b3.Id);

            Assert.Equal(3, freshB2.QuantityReserved);
            Assert.Equal(0, freshB2.QuantityAvailable);

            Assert.Equal(3, freshB1.QuantityReserved);
            Assert.Equal(2, freshB1.QuantityAvailable);

            Assert.Equal(0, freshB3.QuantityReserved);
            Assert.Equal(20, freshB3.QuantityAvailable);
        }

        [Fact]
        public async Task ReserveStockFEFOAsync_ExcludesExpiredAndQuarantinedBatches()
        {
            var (context, uow, service) = CreateTestContext();

            // Expired batch (yesterday)
            var expired = new ProductBatch
            {
                ProductId = 300,
                MerchantId = 1,
                BatchNumber = "BAT-EXPIRED",
                Barcode = "BC-EXP",
                ExpirationDate = DateTime.UtcNow.AddDays(-1),
                QuantityOnHand = 10,
                Status = BatchStatus.Expired,
                LocationBin = "Bin-EXP"
            };

            // Quarantined batch
            var quarantined = new ProductBatch
            {
                ProductId = 300,
                MerchantId = 1,
                BatchNumber = "BAT-QUARANTINED",
                Barcode = "BC-QUAR",
                ExpirationDate = DateTime.UtcNow.AddDays(15),
                QuantityOnHand = 10,
                Status = BatchStatus.Quarantined,
                LocationBin = "Bin-QUAR"
            };

            // Fresh batch
            var fresh = new ProductBatch
            {
                ProductId = 300,
                MerchantId = 1,
                BatchNumber = "BAT-FRESH",
                Barcode = "BC-FRESH",
                ExpirationDate = DateTime.UtcNow.AddDays(15),
                QuantityOnHand = 5,
                Status = BatchStatus.Active,
                LocationBin = "Bin-FRESH"
            };

            await context.ProductBatches.AddRangeAsync(expired, quarantined, fresh);
            await uow.SaveChangesAsync();

            // Request 5 units: Should only reserve from BAT-FRESH
            var res = await service.ReserveStockFEFOAsync(1002, 5002, 300, 1, 5);

            Assert.Single(res);
            Assert.Equal("BAT-FRESH", res[0].BatchNumber);

            // Requesting 6 units should fail with InsufficientStockException because expired/quarantined are blocked
            await Assert.ThrowsAsync<InvalidOperationException>(() =>
                service.ReserveStockFEFOAsync(1003, 5003, 300, 1, 6));
        }

        [Fact]
        public async Task ReleaseReservationAsync_RestoresReservedStock()
        {
            var (context, uow, service) = CreateTestContext();

            var batch = new ProductBatch
            {
                ProductId = 400,
                MerchantId = 1,
                BatchNumber = "BAT-REL",
                Barcode = "BC-REL",
                ExpirationDate = DateTime.UtcNow.AddMonths(1),
                QuantityOnHand = 10,
                QuantityReserved = 0,
                Status = BatchStatus.Active,
                LocationBin = "Bin-REL"
            };
            await context.ProductBatches.AddAsync(batch);
            await uow.SaveChangesAsync();

            await service.ReserveStockFEFOAsync(1004, 5004, 400, 1, 4);

            var reservedBatch = await context.ProductBatches.FindAsync(batch.Id);
            Assert.Equal(4, reservedBatch.QuantityReserved);

            // Release reservation (order cancelled)
            await service.ReleaseReservationAsync(1004, 5004, "Customer Cancelled");

            var releasedBatch = await context.ProductBatches.FindAsync(batch.Id);
            Assert.Equal(0, releasedBatch.QuantityReserved);
            Assert.Equal(10, releasedBatch.QuantityAvailable);

            var resRecord = await context.BatchReservations.FirstOrDefaultAsync(r => r.OrderId == 1004);
            Assert.True(resRecord.IsReleased);
            Assert.NotNull(resRecord.ReleasedDate);
            Assert.Equal("Customer Cancelled", resRecord.ReleaseReason);
        }

        [Fact]
        public async Task DeductReservedStockAsync_PermanentlyDecrementsPhysicalStock()
        {
            var (context, uow, service) = CreateTestContext();

            var batch = new ProductBatch
            {
                ProductId = 500,
                MerchantId = 1,
                BatchNumber = "BAT-DED",
                Barcode = "BC-DED",
                ExpirationDate = DateTime.UtcNow.AddMonths(2),
                QuantityOnHand = 8,
                QuantityReserved = 0,
                Status = BatchStatus.Active,
                LocationBin = "Bin-DED"
            };
            await context.ProductBatches.AddAsync(batch);
            await uow.SaveChangesAsync();

            await service.ReserveStockFEFOAsync(1005, 5005, 500, 1, 8);

            // Deduct stock (order packed & fulfilled)
            await service.DeductReservedStockAsync(1005);

            var updatedBatch = await context.ProductBatches.FindAsync(batch.Id);
            Assert.Equal(0, updatedBatch.QuantityOnHand);
            Assert.Equal(0, updatedBatch.QuantityReserved);
            Assert.Equal(BatchStatus.Depleted, updatedBatch.Status);

            var resRecord = await context.BatchReservations.FirstOrDefaultAsync(r => r.OrderId == 1005);
            Assert.True(resRecord.IsDeducted);
            Assert.NotNull(resRecord.DeductedDate);
        }

        [Fact]
        public async Task VerifyPickItemBarcodeAsync_MatchesValidBarcodeAndRejectsMismatch()
        {
            var (context, uow, service) = CreateTestContext();

            var batch = new ProductBatch
            {
                ProductId = 600,
                MerchantId = 1,
                BatchNumber = "BAT-SCAN",
                Barcode = "890123456789",
                Sku = "SKU-JUICE-ORANGE",
                LocationBin = "Aisle-1, Rack-C, Bin-10",
                ExpirationDate = DateTime.UtcNow.AddMonths(1),
                QuantityOnHand = 15,
                Status = BatchStatus.Active
            };
            await context.ProductBatches.AddAsync(batch);
            await uow.SaveChangesAsync();

            await service.ReserveStockFEFOAsync(1006, 5006, 600, 1, 2);

            // 1. Scan correct barcode
            var validResult = await service.VerifyPickItemBarcodeAsync(1006, 5006, "890123456789");
            Assert.True(validResult.Success);
            Assert.Equal("Aisle-1, Rack-C, Bin-10", validResult.LocationBin);
            Assert.Equal("BAT-SCAN", validResult.BatchNumber);
            Assert.True(validResult.IsLineComplete);

            // 2. Scan correct SKU
            var validSkuResult = await service.VerifyPickItemBarcodeAsync(1006, 5006, "SKU-JUICE-ORANGE");
            Assert.True(validSkuResult.Success);

            // 3. Scan incorrect barcode
            var invalidResult = await service.VerifyPickItemBarcodeAsync(1006, 5006, "WRONG-BARCODE");
            Assert.False(invalidResult.Success);
            Assert.Contains("Barcode mismatch", invalidResult.Message);
        }

        [Fact]
        public async Task AdjustStockAsync_UpdatesQuantityAndDepletedStatus()
        {
            var (context, uow, service) = CreateTestContext();

            var batch = new ProductBatch
            {
                ProductId = 700,
                MerchantId = 1,
                BatchNumber = "BAT-ADJ",
                Barcode = "BC-ADJ",
                ExpirationDate = DateTime.UtcNow.AddMonths(2),
                QuantityOnHand = 10,
                QuantityReserved = 2,
                Status = BatchStatus.Active,
                LocationBin = "Bin-ADJ"
            };
            await context.ProductBatches.AddAsync(batch);
            await uow.SaveChangesAsync();

            // Cannot reduce below reserved
            await Assert.ThrowsAsync<InvalidOperationException>(() =>
                service.AdjustStockAsync(new StockAdjustmentDto { BatchId = batch.Id, QuantityDelta = -9, Reason = "Damaged" }));

            // Adjust by -5 (damaged)
            var adjusted = await service.AdjustStockAsync(new StockAdjustmentDto { BatchId = batch.Id, QuantityDelta = -5, Reason = "5 bottles broken" });
            Assert.Equal(5, adjusted.QuantityOnHand);
            Assert.Equal(2, adjusted.QuantityReserved);
            Assert.Equal(3, adjusted.QuantityAvailable);
            Assert.Contains("5 bottles broken", adjusted.Notes);
        }

        [Fact]
        public async Task GetOrderReservationsAsync_ReturnsCorrectOrderDetailMappingAndBinLocations()
        {
            var (context, uow, service) = CreateTestContext();

            var b1 = new ProductBatch
            {
                ProductId = 801,
                MerchantId = 1,
                BatchNumber = "BAT-801",
                Barcode = "BC-801",
                LocationBin = "Aisle-1, Bin-A",
                ExpirationDate = DateTime.UtcNow.AddMonths(2),
                QuantityOnHand = 10,
                Status = BatchStatus.Active
            };
            var b2 = new ProductBatch
            {
                ProductId = 802,
                MerchantId = 1,
                BatchNumber = "BAT-802",
                Barcode = "BC-802",
                LocationBin = "Aisle-2, Bin-B",
                ExpirationDate = DateTime.UtcNow.AddMonths(3),
                QuantityOnHand = 15,
                Status = BatchStatus.Active
            };
            await context.ProductBatches.AddRangeAsync(b1, b2);
            await uow.SaveChangesAsync();

            await service.ReserveStockFEFOAsync(2001, 7001, 801, 1, 2);
            await service.ReserveStockFEFOAsync(2001, 7002, 802, 1, 3);

            var reservations = await service.GetOrderReservationsAsync(2001);

            Assert.Equal(2, reservations.Count);

            var r1 = reservations.FirstOrDefault(r => r.OrderDetailId == 7001);
            Assert.NotNull(r1);
            Assert.Equal("BAT-801", r1!.BatchNumber);
            Assert.Equal("Aisle-1, Bin-A", r1.LocationBin);
            Assert.Equal(2, r1.Quantity);

            var r2 = reservations.FirstOrDefault(r => r.OrderDetailId == 7002);
            Assert.NotNull(r2);
            Assert.Equal("BAT-802", r2!.BatchNumber);
            Assert.Equal("Aisle-2, Bin-B", r2.LocationBin);
            Assert.Equal(3, r2.Quantity);
        }

        [Fact]
        public async Task MixedOrder_MerchantA_CannotDeductOrPick_MerchantB_Stock()
        {
            var (context, uow, service) = CreateTestContext();

            // Setup: Merchant 1 (Dark Store) and Merchant 2 (External Partner)
            var batchM1 = new ProductBatch
            {
                ProductId = 901,
                MerchantId = 1,
                BatchNumber = "BAT-M1-901",
                Barcode = "BC-M1-901",
                LocationBin = "Bin-M1",
                ExpirationDate = DateTime.UtcNow.AddMonths(2),
                QuantityOnHand = 10,
                Status = BatchStatus.Active
            };
            var batchM2 = new ProductBatch
            {
                ProductId = 902,
                MerchantId = 2,
                BatchNumber = "BAT-M2-902",
                Barcode = "BC-M2-902",
                LocationBin = "Bin-M2",
                ExpirationDate = DateTime.UtcNow.AddMonths(2),
                QuantityOnHand = 10,
                Status = BatchStatus.Active
            };
            await context.ProductBatches.AddRangeAsync(batchM1, batchM2);
            await uow.SaveChangesAsync();

            int orderId = 3001;
            int detailIdM1 = 8001;
            int detailIdM2 = 8002;

            await service.ReserveStockFEFOAsync(orderId, detailIdM1, 901, 1, 3);
            await service.ReserveStockFEFOAsync(orderId, detailIdM2, 902, 2, 4);

            // Merchant 1 attempts to pick Merchant 2's item - must fail
            var pickResultWrongMerchant = await service.VerifyPickItemBarcodeAsync(
                orderId, detailIdM2, "BC-M2-902", pickedBy: "PickerM1", merchantId: 1);
            Assert.False(pickResultWrongMerchant.Success);

            // Merchant 1 picks their own item successfully
            var pickResultM1 = await service.VerifyPickItemBarcodeAsync(
                orderId, detailIdM1, "BC-M1-901", pickedBy: "PickerM1", merchantId: 1);
            Assert.True(pickResultM1.Success);
            Assert.True(pickResultM1.IsOrderFullyPicked); // Fully picked for Merchant 1 scope

            var reservations = await service.GetOrderReservationsAsync(orderId);
            var resM1 = reservations.First(r => r.OrderDetailId == detailIdM1);
            var resM2 = reservations.First(r => r.OrderDetailId == detailIdM2);
            Assert.True(resM1.IsPicked);
            Assert.Equal("PickerM1", resM1.PickedBy);
            Assert.NotNull(resM1.PickedDate);
            Assert.False(resM2.IsPicked); // Merchant 2 item untouched

            // Merchant 1 marks ready / completes picking: deducts only Merchant 1 stock
            await service.DeductReservedStockAsync(orderId, merchantId: 1);

            var b1Updated = await context.ProductBatches.FindAsync(batchM1.Id);
            var b2Updated = await context.ProductBatches.FindAsync(batchM2.Id);

            // Merchant 1 stock is deducted
            Assert.Equal(7, b1Updated!.QuantityOnHand);
            Assert.Equal(0, b1Updated.QuantityReserved);

            // Merchant 2 stock remains protected in reserved state (not deducted!)
            Assert.Equal(10, b2Updated!.QuantityOnHand);
            Assert.Equal(4, b2Updated.QuantityReserved);
        }
    }
}
