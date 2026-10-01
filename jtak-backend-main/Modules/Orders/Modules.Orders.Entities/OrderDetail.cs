using App.Shared.Entities.Enums;
using Solf.Base;
using Solf.Extensions;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;

namespace Modules.Orders.Entities
{
    public class OrderDetail : AuditableEntity
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int Id { get; set; }
        public int Quantity { get; set; }
        public decimal SingleMerchantProfit { get; set; }
        public decimal SinglePrice { get; set; }
        public decimal SingleFinalPrice { get; set; }
        public decimal SingleAdditionalProfit { get; set; }
        public Currency Currency { get; set; }
        public OrderDetailStatus OrderDetailStatus { get; set; }
        public string Warning { get; set; }
        public int ProductId { get; set; }
        public string ProductTitle { get; set; }
        public string ProductUnit { get; set; }
        public string ProductImage { get; set; }
        public int MerchantId { get; set; }
        public string MerchantTitle { get; set; }
        /// <summary>Immutable merchant contract captured when the customer checked out.</summary>
        public decimal CommissionRatePercent { get; set; }
        public bool IsPlatformOwnedSnapshot { get; set; }
        public int OrderId { get; set; }
        public virtual Order Order { get; set; }
        public decimal UnitSalePrice => SingleFinalPrice > 0 ? SingleFinalPrice : SinglePrice;
        public decimal TotalFinalPrice => UnitSalePrice * Quantity;
        public decimal TotalPrice => TotalFinalPrice;
        public OrderDetailDto ToDto() =>
            new()
            {
                Id = Id,
                Quantity = Quantity,
                ProductId = ProductId,
                ProductTitle = ProductTitle,
                ProductUnit = ProductUnit,
                ProductImage = ProductImage,
                MerchantId = MerchantId,
                MerchantTitle = MerchantTitle,
                CommissionRatePercent = CommissionRatePercent,
                IsPlatformOwnedSnapshot = IsPlatformOwnedSnapshot,
                SinglePrice = SinglePrice,
                SingleFinalPrice = SingleFinalPrice,
                SingleMerchantProfit = SingleMerchantProfit,
                SingleAdditionalProfit = SingleAdditionalProfit,
                OrderDetailStatus = OrderDetailStatus,
                Warning = Warning,
                Currency = Currency,
                OrderId = OrderId
            };
    }

    public class OrderDetailDto
    {
        public int Id { get; set; }
        public int Quantity { get; set; }
        public decimal SinglePrice { get; set; }
        public decimal SingleFinalPrice { get; set; }
        public decimal SingleMerchantProfit { get; set; }
        public decimal SingleAdditionalProfit { get; set; }
        /// <summary>Display-only CompareAt / crossed-out original price</summary>
        public decimal CompareAtPrice => SinglePrice;
        /// <summary>Canonical unit sale price charged to customer</summary>
        public decimal UnitSalePrice => SingleFinalPrice > 0m ? SingleFinalPrice : SinglePrice;
        /// <summary>Canonical line total charged to customer: Quantity * UnitSalePrice</summary>
        public decimal TotalPrice => Quantity * (SingleFinalPrice > 0m ? SingleFinalPrice : SinglePrice);
        /// <summary>Display-only total before discount</summary>
        public decimal TotalCompareAtPrice => Quantity * SinglePrice;
        /// <summary>Backward-compatible alias for canonical charged line total</summary>
        public decimal TotalFinalPrice => TotalPrice;
        public Currency Currency { get; set; } = Currency.TRY;
        public string CurrencyString => Currency.ToLocalizedName();
        public OrderDetailStatus OrderDetailStatus { get; set; }
        public string OrderDetailStatusString => OrderDetailStatus.ToLocalizedName();
        public bool IsAccepted => OrderDetailStatus == OrderDetailStatus.MerchantAccepted ||
                                  OrderDetailStatus == OrderDetailStatus.ReadyForPickup ||
                                  OrderDetailStatus == OrderDetailStatus.ShippingStarted ||
                                  OrderDetailStatus == OrderDetailStatus.Delivered;
        public bool IsRejected => OrderDetailStatus == OrderDetailStatus.MerchantRejected;
        public bool IsCanceled => OrderDetailStatus == OrderDetailStatus.CustomerCanceled ||
                                  OrderDetailStatus == OrderDetailStatus.DeliveryCanceled;
        public int AcceptedQuantity => IsAccepted ? Quantity : 0;
        public int RejectedQuantity => IsRejected ? Quantity : 0;
        public decimal MerchantPayable => IsAccepted ? (SingleMerchantProfit > 0m ? SingleMerchantProfit * Quantity : TotalPrice) : 0m;
        public string Warning { get; set; }
        public int ProductId { get; set; }
        public string ProductTitle { get; set; }
        public string ProductUnit { get; set; }
        public string ProductImage { get; set; }
        public int MerchantId { get; set; }
        public string MerchantTitle { get; set; }
        public string MerchantLogo { get; set; }
        public decimal CommissionRatePercent { get; set; }
        public bool IsPlatformOwnedSnapshot { get; set; }
        public int OrderId { get; set; }
    }

    public class DeliveryOrderDetailDto
    {
        public OrderDetailStatus OrderDetailStatus { get; set; }
        public string OrderDetailStatusString => OrderDetailStatus.ToLocalizedName();
        public int MerchantId { get; set; }
        public string MerchantTitle { get; set; }
        public string MerchantLogo { get; set; }
        public decimal Lat { get; set; }
        public decimal Lng { get; set; }
        public string MerchantPhone { get; set; }
        public string MerchantAddress { get; set; }
        public bool IsDarkStore { get; set; }
        public OrderDetailDto[] OrderDetails { get; set; }
        // Terminal canceled/rejected lines remain in the delivery payload so
        // the client can classify history correctly, but they must not be
        // included in the COD amount shown to or collected by the driver.
        public decimal Price => OrderDetails
            .Where(x => x.OrderDetailStatus != OrderDetailStatus.MerchantRejected &&
                        x.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                        x.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled &&
                        x.OrderDetailStatus != OrderDetailStatus.CustomerPending)
            .Sum(x => x.TotalFinalPrice);
    }
}
