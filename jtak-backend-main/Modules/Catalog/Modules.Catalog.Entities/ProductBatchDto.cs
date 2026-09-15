using System;

namespace Modules.Catalog.Entities
{
    public class ProductBatchDto
    {
        public int Id { get; set; }
        public int ProductId { get; set; }
        public string ProductTitle { get; set; }
        public int MerchantId { get; set; }
        public string MerchantTitle { get; set; }
        public string BatchNumber { get; set; }
        public string LotNumber { get; set; }
        public string Barcode { get; set; }
        public string Sku { get; set; }
        public string LocationBin { get; set; }
        public DateTime? ManufactureDate { get; set; }
        public DateTime ExpirationDate { get; set; }
        public int QuantityOnHand { get; set; }
        public int QuantityReserved { get; set; }
        public int QuantityAvailable { get; set; }
        public decimal CostPrice { get; set; }
        public decimal? SellingPrice { get; set; }
        public BatchStatus Status { get; set; }
        public string StatusName => Status.ToString();
        public int DaysUntilExpiry => (int)(ExpirationDate.Date - DateTime.UtcNow.Date).TotalDays;
        public bool IsExpired => ExpirationDate.Date < DateTime.UtcNow.Date;
        public bool IsNearExpiry => !IsExpired && DaysUntilExpiry <= 7;
        public string Notes { get; set; }
    }

    public class CreateProductBatchDto
    {
        public int ProductId { get; set; }
        public int MerchantId { get; set; }
        public string BatchNumber { get; set; }
        public string LotNumber { get; set; }
        public string Barcode { get; set; }
        public string Sku { get; set; }
        public string LocationBin { get; set; }
        public DateTime? ManufactureDate { get; set; }
        public DateTime ExpirationDate { get; set; }
        public int InitialQuantity { get; set; }
        public decimal CostPrice { get; set; }
        public decimal? SellingPrice { get; set; }
        public string Notes { get; set; }
    }

    public class StockAdjustmentDto
    {
        public int BatchId { get; set; }
        public int QuantityDelta { get; set; }
        public string Reason { get; set; }
    }

    public class BatchPickVerificationDto
    {
        public int OrderId { get; set; }
        public int OrderDetailId { get; set; }
        public string ScannedBarcode { get; set; }
    }

    public class BatchPickResultDto
    {
        public bool Success { get; set; }
        public string Message { get; set; }
        public int OrderDetailId { get; set; }
        public int ProductId { get; set; }
        public string ProductTitle { get; set; }
        public string ScannedBarcode { get; set; }
        public string LocationBin { get; set; }
        public string BatchNumber { get; set; }
        public int QuantityRequired { get; set; }
        public int QuantityPicked { get; set; }
        public bool IsLineComplete { get; set; }
        public bool IsOrderFullyPicked { get; set; }
    }

    public class BatchReservationDto
    {
        public int ReservationId { get; set; }
        public int OrderDetailId { get; set; }
        public int ProductBatchId { get; set; }
        public string BatchNumber { get; set; }
        public string Barcode { get; set; }
        public string LocationBin { get; set; }
        public DateTime ExpirationDate { get; set; }
        public int Quantity { get; set; }
        public bool IsDeducted { get; set; }
        public bool IsReleased { get; set; }
        public bool IsPicked { get; set; }
        public DateTime? PickedDate { get; set; }
        public string PickedBy { get; set; }
    }

    public class WarehousePickingItemDto
    {
        public int OrderDetailId { get; set; }
        public int ProductId { get; set; }
        public string ProductTitle { get; set; }
        public string ProductImage { get; set; }
        public string ProductUnit { get; set; }
        public int Quantity { get; set; }
        public string LocationBin { get; set; }
        public string BatchNumber { get; set; }
        public string LotNumber { get; set; }
        public string Barcode { get; set; }
        public DateTime? ExpirationDate { get; set; }
        public bool IsPicked { get; set; }
    }

    public class InventoryBatchKpiDto
    {
        public int TotalBatches { get; set; }
        public int ActiveBatches { get; set; }
        public int NearExpiryBatches { get; set; }
        public int ExpiredBatches { get; set; }
        public int QuarantinedBatches { get; set; }
        public int DepletedBatches { get; set; }
        public int TotalQuantityOnHand { get; set; }
        public int TotalQuantityReserved { get; set; }
        public int TotalQuantityAvailable { get; set; }
    }

    public class BatchProductLookupDto
    {
        public int Id { get; set; }
        public string Title { get; set; }
        public string Barcode { get; set; }
        public string Sku { get; set; }
        public int MerchantId { get; set; }
        public string MerchantTitle { get; set; }
        public decimal Price { get; set; }
        public string Photo { get; set; }
    }

    public class BatchMerchantLookupDto
    {
        public int Id { get; set; }
        public string Title { get; set; }
    }

    public class QuarantineBatchDto
    {
        public int BatchId { get; set; }
        public bool Quarantine { get; set; } = true;
        public string Reason { get; set; }
    }
}

