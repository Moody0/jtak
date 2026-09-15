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
    public interface IInventoryBatchService
    {
        Task<ProductBatchDto> CreateBatchAsync(CreateProductBatchDto dto, string createdBy = null);
        Task<ProductBatchDto> GetBatchByIdAsync(int id);
        Task<ProductBatchDto> GetBatchByBarcodeAsync(string barcode, int? merchantId = null);
        Task<List<ProductBatchDto>> GetBatchesByProductAsync(int productId, int? merchantId = null);
        Task<List<ProductBatchDto>> GetBatchesByMerchantAsync(int merchantId, BatchStatus? status = null);
        Task<List<ProductBatchDto>> GetAllBatchesAsync(int? merchantId = null, int? productId = null, BatchStatus? status = null, string searchTerm = null);
        Task<InventoryBatchKpiDto> GetBatchKpisAsync(int? merchantId = null);
        Task<List<ProductBatchDto>> GetAllAlertsAsync(int? merchantId = null, int daysThreshold = 7);
        Task<ProductBatchDto> AdjustStockAsync(StockAdjustmentDto dto, string updatedBy = null);
        Task<ProductBatchDto> ToggleQuarantineAsync(int batchId, bool quarantine, string reason, string updatedBy = null);
        Task<List<ProductBatchDto>> GetNearExpiryOrExpiredBatchesAsync(int merchantId, int daysThreshold = 7);
        Task<List<BatchReservationDto>> ReserveStockFEFOAsync(int orderId, int orderDetailId, int productId, int merchantId, int quantity, int minDaysToExpiry = 1);
        Task ReleaseReservationAsync(int orderId, int? orderDetailId = null, string reason = "Order Cancelled", int? merchantId = null);
        Task DeductReservedStockAsync(int orderId, int? orderDetailId = null, int? merchantId = null);
        Task<BatchPickResultDto> VerifyPickItemBarcodeAsync(int orderId, int orderDetailId, string scannedBarcode, string pickedBy = null, int? merchantId = null);
        Task<List<BatchReservationDto>> GetOrderReservationsAsync(int orderId);
        Task<List<BatchProductLookupDto>> GetProductLookupAsync(string searchTerm = null, int? merchantId = null, int limit = 25);
        Task<List<BatchMerchantLookupDto>> GetMerchantLookupAsync();
    }
}
