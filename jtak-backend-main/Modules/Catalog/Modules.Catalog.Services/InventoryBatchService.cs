using App.Catalog.Data;
using App.Shared.Data.MultiContext;
using Microsoft.EntityFrameworkCore;
using Modules.Catalog.Entities;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace Modules.Catalog.Services
{
    public class InventoryBatchService : IInventoryBatchService
    {
        private readonly CatalogDbContext _context;
        private readonly ICatalogUnitOfWork _uow;

        public InventoryBatchService(CatalogDbContext context, ICatalogUnitOfWork uow)
        {
            _context = context ?? throw new ArgumentNullException(nameof(context));
            _uow = uow ?? throw new ArgumentNullException(nameof(uow));
        }

        public async Task<ProductBatchDto> CreateBatchAsync(CreateProductBatchDto dto, string createdBy = null)
        {
            if (dto == null) throw new ArgumentNullException(nameof(dto));
            if (dto.InitialQuantity <= 0)
                throw new ArgumentException("Initial quantity must be greater than zero.", nameof(dto.InitialQuantity));
            if (string.IsNullOrWhiteSpace(dto.BatchNumber))
                throw new ArgumentException("Batch number is required.", nameof(dto.BatchNumber));
            if (string.IsNullOrWhiteSpace(dto.Barcode))
                throw new ArgumentException("Barcode is required.", nameof(dto.Barcode));

            var now = DateTime.UtcNow;
            var isExpired = dto.ExpirationDate.Date <= now.Date;
            var isNearExpiry = !isExpired && (dto.ExpirationDate.Date - now.Date).TotalDays <= 7;

            var status = isExpired ? BatchStatus.Expired : (isNearExpiry ? BatchStatus.NearExpiry : BatchStatus.Active);

            var batch = new ProductBatch
            {
                ProductId = dto.ProductId,
                MerchantId = dto.MerchantId,
                BatchNumber = dto.BatchNumber.Trim(),
                LotNumber = dto.LotNumber?.Trim(),
                Barcode = dto.Barcode.Trim(),
                Sku = dto.Sku?.Trim(),
                LocationBin = dto.LocationBin?.Trim(),
                ManufactureDate = dto.ManufactureDate,
                ExpirationDate = dto.ExpirationDate,
                QuantityOnHand = dto.InitialQuantity,
                QuantityReserved = 0,
                CostPrice = dto.CostPrice,
                SellingPrice = dto.SellingPrice,
                Status = status,
                Notes = dto.Notes,
                CreatedBy = createdBy ?? "System",
                CreatedDate = now
            };

            await _context.ProductBatches.AddAsync(batch);
            await _uow.SaveChangesAsync();

            return await GetBatchByIdAsync(batch.Id);
        }

        public async Task<ProductBatchDto> GetBatchByIdAsync(int id)
        {
            var batch = await _context.ProductBatches
                .AsNoTracking()
                .Include(b => b.Product)
                .Include(b => b.Merchant)
                .FirstOrDefaultAsync(b => b.Id == id && b.DeletionDate == null);

            return MapToDto(batch);
        }

        public async Task<ProductBatchDto> GetBatchByBarcodeAsync(string barcode, int? merchantId = null)
        {
            if (string.IsNullOrWhiteSpace(barcode)) return null;
            var cleanBarcode = barcode.Trim();

            var query = _context.ProductBatches
                .AsNoTracking()
                .Include(b => b.Product)
                .Include(b => b.Merchant)
                .Where(b => b.DeletionDate == null && (b.Barcode == cleanBarcode || b.Sku == cleanBarcode));

            if (merchantId.HasValue)
            {
                query = query.Where(b => b.MerchantId == merchantId.Value);
            }

            var batch = await query.FirstOrDefaultAsync();
            return MapToDto(batch);
        }

        public async Task<List<ProductBatchDto>> GetBatchesByProductAsync(int productId, int? merchantId = null)
        {
            var query = _context.ProductBatches
                .AsNoTracking()
                .Include(b => b.Product)
                .Include(b => b.Merchant)
                .Where(b => b.ProductId == productId && b.DeletionDate == null);

            if (merchantId.HasValue)
            {
                query = query.Where(b => b.MerchantId == merchantId.Value);
            }

            var batches = await query
                .OrderBy(b => b.ExpirationDate)
                .ToListAsync();

            return batches.Select(MapToDto).ToList();
        }

        public async Task<List<ProductBatchDto>> GetBatchesByMerchantAsync(int merchantId, BatchStatus? status = null)
        {
            var query = _context.ProductBatches
                .AsNoTracking()
                .Include(b => b.Product)
                .Include(b => b.Merchant)
                .Where(b => b.MerchantId == merchantId && b.DeletionDate == null);

            if (status.HasValue)
            {
                query = query.Where(b => b.Status == status.Value);
            }

            var batches = await query
                .OrderBy(b => b.ExpirationDate)
                .ToListAsync();

            return batches.Select(MapToDto).ToList();
        }

        public async Task<List<ProductBatchDto>> GetAllBatchesAsync(int? merchantId = null, int? productId = null, BatchStatus? status = null, string searchTerm = null)
        {
            var query = _context.ProductBatches
                .AsNoTracking()
                .Include(b => b.Product)
                .Include(b => b.Merchant)
                .Where(b => b.DeletionDate == null);

            if (merchantId.HasValue)
                query = query.Where(b => b.MerchantId == merchantId.Value);

            if (productId.HasValue)
                query = query.Where(b => b.ProductId == productId.Value);

            if (status.HasValue)
                query = query.Where(b => b.Status == status.Value);

            if (!string.IsNullOrWhiteSpace(searchTerm))
            {
                var st = searchTerm.Trim().ToLower();
                query = query.Where(b =>
                    b.BatchNumber.ToLower().Contains(st) ||
                    b.Barcode.ToLower().Contains(st) ||
                    (b.Sku != null && b.Sku.ToLower().Contains(st)) ||
                    (b.Product != null && b.Product.Title.ToLower().Contains(st)) ||
                    (b.LocationBin != null && b.LocationBin.ToLower().Contains(st)));
            }

            var batches = await query
                .OrderBy(b => b.ExpirationDate)
                .ToListAsync();

            return batches.Select(MapToDto).ToList();
        }

        public async Task<InventoryBatchKpiDto> GetBatchKpisAsync(int? merchantId = null)
        {
            var now = DateTime.UtcNow.Date;
            var nearExpiryThreshold = now.AddDays(7);

            var query = _context.ProductBatches
                .AsNoTracking()
                .Where(b => b.DeletionDate == null);

            if (merchantId.HasValue)
                query = query.Where(b => b.MerchantId == merchantId.Value);

            var list = await query.ToListAsync();

            return new InventoryBatchKpiDto
            {
                TotalBatches = list.Count,
                ActiveBatches = list.Count(b => b.Status == BatchStatus.Active && b.ExpirationDate.Date > nearExpiryThreshold),
                NearExpiryBatches = list.Count(b => (b.Status == BatchStatus.NearExpiry || (b.ExpirationDate.Date > now && b.ExpirationDate.Date <= nearExpiryThreshold)) && b.QuantityOnHand > 0),
                ExpiredBatches = list.Count(b => (b.Status == BatchStatus.Expired || b.ExpirationDate.Date <= now) && b.QuantityOnHand > 0),
                QuarantinedBatches = list.Count(b => b.Status == BatchStatus.Quarantined),
                DepletedBatches = list.Count(b => b.Status == BatchStatus.Depleted || b.QuantityOnHand <= 0),
                TotalQuantityOnHand = list.Sum(b => b.QuantityOnHand),
                TotalQuantityReserved = list.Sum(b => b.QuantityReserved),
                TotalQuantityAvailable = list.Sum(b => Math.Max(0, b.QuantityOnHand - b.QuantityReserved))
            };
        }

        public async Task<List<ProductBatchDto>> GetAllAlertsAsync(int? merchantId = null, int daysThreshold = 7)
        {
            var now = DateTime.UtcNow.Date;
            var thresholdDate = now.AddDays(daysThreshold);

            var query = _context.ProductBatches
                .Include(b => b.Product)
                .Include(b => b.Merchant)
                .Where(b => b.DeletionDate == null && b.QuantityOnHand > 0 && b.ExpirationDate.Date <= thresholdDate);

            if (merchantId.HasValue)
                query = query.Where(b => b.MerchantId == merchantId.Value);

            var batches = await query
                .OrderBy(b => b.ExpirationDate)
                .ToListAsync();

            bool modified = false;
            foreach (var b in batches)
            {
                if (b.ExpirationDate.Date <= now && b.Status != BatchStatus.Expired)
                {
                    b.Status = BatchStatus.Expired;
                    modified = true;
                }
                else if (b.ExpirationDate.Date > now && b.ExpirationDate.Date <= thresholdDate && b.Status == BatchStatus.Active)
                {
                    b.Status = BatchStatus.NearExpiry;
                    modified = true;
                }
            }

            if (modified)
            {
                await _uow.SaveChangesAsync();
            }

            return batches.Select(MapToDto).ToList();
        }

        public async Task<ProductBatchDto> ToggleQuarantineAsync(int batchId, bool quarantine, string reason, string updatedBy = null)
        {
            var batch = await _context.ProductBatches.FirstOrDefaultAsync(b => b.Id == batchId && b.DeletionDate == null);
            if (batch == null)
                throw new KeyNotFoundException($"ProductBatch with ID {batchId} was not found.");

            if (quarantine)
            {
                batch.Status = BatchStatus.Quarantined;
            }
            else
            {
                var now = DateTime.UtcNow.Date;
                if (batch.QuantityOnHand <= 0)
                    batch.Status = BatchStatus.Depleted;
                else if (batch.ExpirationDate.Date <= now)
                    batch.Status = BatchStatus.Expired;
                else if ((batch.ExpirationDate.Date - now).TotalDays <= 7)
                    batch.Status = BatchStatus.NearExpiry;
                else
                    batch.Status = BatchStatus.Active;
            }

            batch.UpdatedBy = updatedBy ?? "Admin";
            batch.UpdatedDate = DateTime.UtcNow;

            if (!string.IsNullOrWhiteSpace(reason))
            {
                var action = quarantine ? "Quarantined" : "Released from quarantine";
                batch.Notes = string.IsNullOrWhiteSpace(batch.Notes)
                    ? $"{action} ({DateTime.UtcNow:yyyy-MM-dd}): {reason}"
                    : $"{batch.Notes} | {action} ({DateTime.UtcNow:yyyy-MM-dd}): {reason}";
            }

            await _uow.SaveChangesAsync();
            return await GetBatchByIdAsync(batch.Id);
        }

        public async Task<List<BatchProductLookupDto>> GetProductLookupAsync(string searchTerm = null, int? merchantId = null, int limit = 25)
        {
            var query = _context.MerchantProducts
                .AsNoTracking()
                .Include(mp => mp.Product)
                .Include(mp => mp.Merchant)
                .Where(mp => mp.Product != null && mp.Product.DeletionDate == null && mp.Product.Active);

            if (merchantId.HasValue)
            {
                query = query.Where(mp => mp.MerchantId == merchantId.Value);
            }

            if (!string.IsNullOrWhiteSpace(searchTerm))
            {
                var st = searchTerm.Trim().ToLower();
                query = query.Where(mp =>
                    mp.Product.Title.ToLower().Contains(st) ||
                    (mp.Product.TitleEn != null && mp.Product.TitleEn.ToLower().Contains(st)) ||
                    (mp.Product.Description != null && mp.Product.Description.ToLower().Contains(st)));
            }

            var items = await query.Take(limit).ToListAsync();

            return items.Select(mp => new BatchProductLookupDto
            {
                Id = mp.ProductId,
                Title = mp.Product.Title,
                MerchantId = mp.MerchantId,
                MerchantTitle = mp.Merchant?.Title,
                Price = mp.MerchantPrice,
                Photo = mp.Product.Photos?.Split(',', StringSplitOptions.RemoveEmptyEntries).FirstOrDefault(),
                Sku = $"SKU-{mp.ProductId:D5}",
                Barcode = $"200{mp.ProductId:D6}"
            }).ToList();
        }

        public async Task<List<BatchMerchantLookupDto>> GetMerchantLookupAsync()
        {
            return await _context.Merchants
                .AsNoTracking()
                .Where(m => m.DeletionDate == null && m.Active)
                .OrderBy(m => m.Title)
                .Select(m => new BatchMerchantLookupDto
                {
                    Id = m.Id,
                    Title = m.Title
                })
                .ToListAsync();
        }

        public async Task<ProductBatchDto> AdjustStockAsync(StockAdjustmentDto dto, string updatedBy = null)
        {
            if (dto == null) throw new ArgumentNullException(nameof(dto));

            var batch = await _context.ProductBatches.FirstOrDefaultAsync(b => b.Id == dto.BatchId && b.DeletionDate == null);
            if (batch == null)
                throw new KeyNotFoundException($"ProductBatch with ID {dto.BatchId} was not found.");

            var newQuantity = batch.QuantityOnHand + dto.QuantityDelta;
            if (newQuantity < batch.QuantityReserved)
            {
                throw new InvalidOperationException($"Cannot adjust stock to {newQuantity} units because {batch.QuantityReserved} units are currently reserved.");
            }

            batch.QuantityOnHand = newQuantity;
            batch.UpdatedBy = updatedBy ?? "System";
            batch.UpdatedDate = DateTime.UtcNow;

            if (batch.QuantityOnHand <= 0)
            {
                batch.Status = BatchStatus.Depleted;
            }
            else if (batch.ExpirationDate.Date <= DateTime.UtcNow.Date)
            {
                batch.Status = BatchStatus.Expired;
            }
            else if ((batch.ExpirationDate.Date - DateTime.UtcNow.Date).TotalDays <= 7)
            {
                batch.Status = BatchStatus.NearExpiry;
            }
            else
            {
                batch.Status = BatchStatus.Active;
            }

            if (!string.IsNullOrWhiteSpace(dto.Reason))
            {
                batch.Notes = string.IsNullOrWhiteSpace(batch.Notes)
                    ? $"Adjustment ({DateTime.UtcNow:yyyy-MM-dd}): {dto.Reason}"
                    : $"{batch.Notes} | Adjustment ({DateTime.UtcNow:yyyy-MM-dd}): {dto.Reason}";
            }

            await _uow.SaveChangesAsync();
            return await GetBatchByIdAsync(batch.Id);
        }

        public async Task<List<ProductBatchDto>> GetNearExpiryOrExpiredBatchesAsync(int merchantId, int daysThreshold = 7)
        {
            var now = DateTime.UtcNow.Date;
            var thresholdDate = now.AddDays(daysThreshold);

            var batches = await _context.ProductBatches
                .Include(b => b.Product)
                .Include(b => b.Merchant)
                .Where(b => b.MerchantId == merchantId && b.DeletionDate == null && b.QuantityOnHand > 0 && b.ExpirationDate <= thresholdDate)
                .OrderBy(b => b.ExpirationDate)
                .ToListAsync();

            // Sync status if out of date
            bool modified = false;
            foreach (var b in batches)
            {
                if (b.ExpirationDate.Date <= now && b.Status != BatchStatus.Expired)
                {
                    b.Status = BatchStatus.Expired;
                    modified = true;
                }
                else if (b.ExpirationDate.Date > now && b.ExpirationDate.Date <= thresholdDate && b.Status == BatchStatus.Active)
                {
                    b.Status = BatchStatus.NearExpiry;
                    modified = true;
                }
            }

            if (modified)
            {
                await _uow.SaveChangesAsync();
            }

            return batches.Select(b => MapToDto(b)).ToList();
        }

        /// <summary>
        /// Allocates stock using First-Expired-First-Out (FEFO) strategy.
        /// Excludes expired batches and batches expiring within minDaysToExpiry threshold.
        /// </summary>
        public async Task<List<BatchReservationDto>> ReserveStockFEFOAsync(int orderId, int orderDetailId, int productId, int merchantId, int quantity, int minDaysToExpiry = 1)
        {
            if (quantity <= 0)
                throw new ArgumentException("Reservation quantity must be greater than zero.", nameof(quantity));

            var isBatchManaged = await _context.ProductBatches.AnyAsync(b => b.ProductId == productId && b.MerchantId == merchantId && b.DeletionDate == null);
            if (!isBatchManaged)
            {
                // Item is not batch-tracked (e.g., third-party restaurant on-demand preparation)
                return new List<BatchReservationDto>();
            }

            var minValidDate = DateTime.UtcNow.Date.AddDays(minDaysToExpiry);

            // Fetch candidate batches ordered by ExpirationDate ASC (FEFO)
            var batches = await _context.ProductBatches
                .Where(b => b.ProductId == productId &&
                            b.MerchantId == merchantId &&
                            b.DeletionDate == null &&
                            b.Status != BatchStatus.Expired &&
                            b.Status != BatchStatus.Quarantined &&
                            b.Status != BatchStatus.Depleted &&
                            b.ExpirationDate > minValidDate &&
                            b.QuantityOnHand > b.QuantityReserved)
                .OrderBy(b => b.ExpirationDate)
                .ThenBy(b => b.CreatedDate)
                .ToListAsync();

            var totalAvailable = batches.Sum(b => b.QuantityOnHand - b.QuantityReserved);
            if (totalAvailable < quantity)
            {
                throw new InvalidOperationException(
                    $"Insufficient fresh inventory for Product ID {productId} at Merchant {merchantId}. " +
                    $"Required: {quantity}, Fresh Available: {totalAvailable}.");
            }

            var remainingToReserve = quantity;
            var reservations = new List<BatchReservation>();

            foreach (var batch in batches)
            {
                if (remainingToReserve <= 0) break;

                var availableInBatch = batch.QuantityOnHand - batch.QuantityReserved;
                var allocate = Math.Min(remainingToReserve, availableInBatch);

                batch.QuantityReserved += allocate;
                remainingToReserve -= allocate;

                var reservation = new BatchReservation
                {
                    ProductBatchId = batch.Id,
                    OrderId = orderId,
                    OrderDetailId = orderDetailId,
                    Quantity = allocate,
                    IsDeducted = false,
                    IsReleased = false,
                    CreatedDate = DateTime.UtcNow,
                    CreatedBy = "FEFO-Engine"
                };

                await _context.BatchReservations.AddAsync(reservation);
                reservations.Add(reservation);
            }

            await _uow.SaveChangesAsync();

            return reservations.Select(r => new BatchReservationDto
            {
                ReservationId = r.Id,
                OrderDetailId = r.OrderDetailId,
                ProductBatchId = r.ProductBatchId,
                BatchNumber = r.ProductBatch?.BatchNumber ?? batches.First(b => b.Id == r.ProductBatchId).BatchNumber,
                Barcode = r.ProductBatch?.Barcode ?? batches.First(b => b.Id == r.ProductBatchId).Barcode,
                LocationBin = r.ProductBatch?.LocationBin ?? batches.First(b => b.Id == r.ProductBatchId).LocationBin,
                ExpirationDate = r.ProductBatch?.ExpirationDate ?? batches.First(b => b.Id == r.ProductBatchId).ExpirationDate,
                Quantity = r.Quantity,
                IsDeducted = r.IsDeducted,
                IsReleased = r.IsReleased
            }).ToList();
        }

        public async Task ReleaseReservationAsync(int orderId, int? orderDetailId = null, string reason = "Order Cancelled", int? merchantId = null)
        {
            var query = _context.BatchReservations
                .Include(r => r.ProductBatch)
                .Where(r => r.OrderId == orderId && !r.IsReleased && !r.IsDeducted);

            if (orderDetailId.HasValue)
            {
                query = query.Where(r => r.OrderDetailId == orderDetailId.Value);
            }

            if (merchantId.HasValue)
            {
                query = query.Where(r => r.ProductBatch.MerchantId == merchantId.Value);
            }

            var reservations = await query.ToListAsync();
            if (!reservations.Any()) return;

            var batchIds = reservations.Select(r => r.ProductBatchId).Distinct().ToList();
            var batches = await _context.ProductBatches
                .Where(b => batchIds.Contains(b.Id))
                .ToDictionaryAsync(b => b.Id);

            var now = DateTime.UtcNow;
            foreach (var res in reservations)
            {
                if (batches.TryGetValue(res.ProductBatchId, out var batch))
                {
                    batch.QuantityReserved = Math.Max(0, batch.QuantityReserved - res.Quantity);
                }
                res.IsReleased = true;
                res.ReleasedDate = now;
                res.ReleaseReason = reason;
            }

            await _uow.SaveChangesAsync();
        }

        public async Task DeductReservedStockAsync(int orderId, int? orderDetailId = null, int? merchantId = null)
        {
            var query = _context.BatchReservations
                .Include(r => r.ProductBatch)
                .Where(r => r.OrderId == orderId && !r.IsDeducted && !r.IsReleased);

            if (orderDetailId.HasValue)
            {
                query = query.Where(r => r.OrderDetailId == orderDetailId.Value);
            }

            if (merchantId.HasValue)
            {
                query = query.Where(r => r.ProductBatch.MerchantId == merchantId.Value);
            }

            var reservations = await query.ToListAsync();
            if (!reservations.Any()) return;

            var batchIds = reservations.Select(r => r.ProductBatchId).Distinct().ToList();
            var batches = await _context.ProductBatches
                .Where(b => batchIds.Contains(b.Id))
                .ToDictionaryAsync(b => b.Id);

            var now = DateTime.UtcNow;
            foreach (var res in reservations)
            {
                if (batches.TryGetValue(res.ProductBatchId, out var batch))
                {
                    batch.QuantityOnHand = Math.Max(0, batch.QuantityOnHand - res.Quantity);
                    batch.QuantityReserved = Math.Max(0, batch.QuantityReserved - res.Quantity);

                    if (batch.QuantityOnHand <= 0)
                    {
                        batch.Status = BatchStatus.Depleted;
                    }
                }
                res.IsDeducted = true;
                res.DeductedDate = now;
            }

            await _uow.SaveChangesAsync();
        }

        public async Task<BatchPickResultDto> VerifyPickItemBarcodeAsync(int orderId, int orderDetailId, string scannedBarcode, string pickedBy = null, int? merchantId = null)
        {
            if (string.IsNullOrWhiteSpace(scannedBarcode))
            {
                return new BatchPickResultDto
                {
                    Success = false,
                    Message = "Scanned barcode cannot be empty.",
                    OrderDetailId = orderDetailId
                };
            }

            var cleanScan = scannedBarcode.Trim();

            // Find reservations for this order line
            var query = _context.BatchReservations
                .Include(r => r.ProductBatch)
                .Where(r => r.OrderId == orderId && r.OrderDetailId == orderDetailId && !r.IsReleased);

            if (merchantId.HasValue)
            {
                query = query.Where(r => r.ProductBatch.MerchantId == merchantId.Value);
            }

            var reservations = await query.ToListAsync();

            if (!reservations.Any())
            {
                return new BatchPickResultDto
                {
                    Success = false,
                    Message = $"No active batch reservation found for Order #{orderId}, Line #{orderDetailId}.",
                    OrderDetailId = orderDetailId
                };
            }

            var batchIds = reservations.Select(r => r.ProductBatchId).Distinct().ToList();
            var batches = await _context.ProductBatches
                .Include(b => b.Product)
                .Where(b => batchIds.Contains(b.Id) && b.DeletionDate == null)
                .ToListAsync();

            var matchedBatch = batches.FirstOrDefault(b =>
                string.Equals(b.Barcode?.Trim(), cleanScan, StringComparison.OrdinalIgnoreCase) ||
                string.Equals(b.Sku?.Trim(), cleanScan, StringComparison.OrdinalIgnoreCase));

            if (matchedBatch == null)
            {
                var expectedBarcodes = string.Join(", ", batches.Select(b => b.Barcode).Where(b => b != null));
                var productName = batches.FirstOrDefault()?.Product?.Title ?? $"Product #{batches.FirstOrDefault()?.ProductId}";

                return new BatchPickResultDto
                {
                    Success = false,
                    Message = $"Barcode mismatch! Scanned '{cleanScan}' does not match expected batch barcode(s) [{expectedBarcodes}] for {productName}.",
                    OrderDetailId = orderDetailId,
                    ScannedBarcode = cleanScan
                };
            }

            // Mark only the reservation(s) belonging to the scanned batch as
            // picked. A line may be split across multiple FEFO batches; scanning
            // one barcode must not silently mark the other batches as picked.
            var now = DateTime.UtcNow;
            var matchedReservations = reservations
                .Where(r => r.ProductBatchId == matchedBatch.Id && !r.IsDeducted && !r.IsReleased)
                .ToList();
            if (!matchedReservations.Any())
            {
                return new BatchPickResultDto
                {
                    Success = false,
                    Message = "الدفعة الممسوحة ليست ضمن الكمية المحجوزة لهذا السطر.",
                    OrderDetailId = orderDetailId,
                    ScannedBarcode = cleanScan
                };
            }

            foreach (var res in matchedReservations)
            {
                res.IsPicked = true;
                res.PickedDate = now;
                res.PickedBy = pickedBy;
            }
            await _uow.SaveChangesAsync();

            var totalRequired = reservations.Sum(r => r.Quantity);
            var quantityPicked = reservations.Where(r => r.IsPicked).Sum(r => r.Quantity);
            var isLineComplete = reservations.All(r => r.IsPicked);

            // Check if all batch-managed reservations for this order (scoped to merchant if provided) are fully picked
            var allOrderReservations = await _context.BatchReservations
                .Include(r => r.ProductBatch)
                .Where(r => r.OrderId == orderId && !r.IsReleased && !r.IsDeducted)
                .ToListAsync();

            if (merchantId.HasValue)
            {
                allOrderReservations = allOrderReservations.Where(r => r.ProductBatch?.MerchantId == merchantId.Value).ToList();
            }

            var isFullyPicked = allOrderReservations.All(r => r.IsPicked);

            return new BatchPickResultDto
            {
                Success = true,
                Message = "Item verified successfully!",
                OrderDetailId = orderDetailId,
                ProductId = matchedBatch.ProductId,
                ProductTitle = matchedBatch.Product?.Title,
                ScannedBarcode = cleanScan,
                LocationBin = matchedBatch.LocationBin,
                BatchNumber = matchedBatch.BatchNumber,
                QuantityRequired = totalRequired,
                QuantityPicked = quantityPicked,
                IsLineComplete = isLineComplete,
                IsOrderFullyPicked = isFullyPicked
            };
        }

        public async Task<List<BatchReservationDto>> GetOrderReservationsAsync(int orderId)
        {
            var reservations = await _context.BatchReservations
                .AsNoTracking()
                .Where(r => r.OrderId == orderId)
                .ToListAsync();

            if (!reservations.Any()) return new List<BatchReservationDto>();

            var batchIds = reservations.Select(r => r.ProductBatchId).Distinct().ToList();
            var batches = await _context.ProductBatches
                .AsNoTracking()
                .Where(b => batchIds.Contains(b.Id))
                .ToDictionaryAsync(b => b.Id);

            return reservations.Select(r =>
            {
                batches.TryGetValue(r.ProductBatchId, out var b);
                return new BatchReservationDto
                {
                    ReservationId = r.Id,
                    OrderDetailId = r.OrderDetailId,
                    ProductBatchId = r.ProductBatchId,
                    BatchNumber = b?.BatchNumber,
                    Barcode = b?.Barcode,
                    LocationBin = b?.LocationBin,
                    ExpirationDate = b?.ExpirationDate ?? default,
                    Quantity = r.Quantity,
                    IsDeducted = r.IsDeducted,
                    IsReleased = r.IsReleased,
                    IsPicked = r.IsPicked,
                    PickedDate = r.PickedDate,
                    PickedBy = r.PickedBy
                };
            }).ToList();
        }

        private static ProductBatchDto MapToDto(ProductBatch b)
        {
            if (b == null) return null;
            return new ProductBatchDto
            {
                Id = b.Id,
                ProductId = b.ProductId,
                ProductTitle = b.Product?.Title,
                MerchantId = b.MerchantId,
                MerchantTitle = b.Merchant?.Title,
                BatchNumber = b.BatchNumber,
                LotNumber = b.LotNumber,
                Barcode = b.Barcode,
                Sku = b.Sku,
                LocationBin = b.LocationBin,
                ManufactureDate = b.ManufactureDate,
                ExpirationDate = b.ExpirationDate,
                QuantityOnHand = b.QuantityOnHand,
                QuantityReserved = b.QuantityReserved,
                QuantityAvailable = Math.Max(0, b.QuantityOnHand - b.QuantityReserved),
                CostPrice = b.CostPrice,
                SellingPrice = b.SellingPrice,
                Status = b.Status,
                Notes = b.Notes
            };
        }
    }
}
