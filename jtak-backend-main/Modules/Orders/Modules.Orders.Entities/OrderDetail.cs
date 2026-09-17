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
        public int OrderId { get; set; }
        public virtual Order Order { get; set; }
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
                SinglePrice = SinglePrice,
                SingleFinalPrice = SingleFinalPrice,
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
        public decimal TotalPrice => Quantity * SinglePrice;
        public decimal TotalFinalPrice => Quantity * SingleFinalPrice;
        public Currency Currency { get; set; } = Currency.TRY;
        public string CurrencyString => Currency.ToLocalizedName();
        public OrderDetailStatus OrderDetailStatus { get; set; }
        public string OrderDetailStatusString => OrderDetailStatus.ToLocalizedName();
        public string Warning { get; set; }
        public int ProductId { get; set; }
        public string ProductTitle { get; set; }
        public string ProductUnit { get; set; }
        public string ProductImage { get; set; }
        public int MerchantId { get; set; }
        public string MerchantTitle { get; set; }
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
