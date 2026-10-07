using App.Shared.Services.Pricing;
using Modules.Catalog.Entities;
using Modules.Orders.Entities;
using Xunit;

namespace Modules.Accounting.Tests;

public class MerchantBaseOrderMoneyTests
{
    [Theory]
    [InlineData(0, 605, 55)]
    [InlineData(5, 578, 28)]
    [InlineData(9, 556, 6)]
    [InlineData(10, 550, 0)]
    [InlineData(50, 550, 0)]
    public void NewOrderAndInvoiceUseCapturedBaseAndSeparateDelivery(
        decimal discountPercent, decimal customerUnitPrice, decimal platformUnitShare)
    {
        var quote = MerchantProductPricing.Calculate(550m, 10m, discountPercent);
        Assert.Equal(customerUnitPrice, quote.FinalPrice);
        var detail = new OrderDetail {
            MerchantId = 27, Quantity = 4, SingleMerchantProfit = quote.MerchantPrice,
            SinglePrice = quote.Price, SingleFinalPrice = quote.FinalPrice,
            CommissionRatePercent = 10m,
            OrderDetailStatus = OrderDetailStatus.MerchantAccepted
        };
        var service = new OrderMoneyCalculationService();
        var money = service.CalculateOrderMoney(new[] { detail }, 200m, PaymentMethod.PayOnDelivery,
            merchantCommissionInfos: new[] { new MerchantCommissionInfo {
                MerchantId = 27, CommissionRatePercent = 10m, IsDarkStore = false
            } }, captainEarning: 75m, commissionUsesMerchantBase: true);
        var invoice = service.CalculateMerchantBill(new[] { detail }, 10m,
            PaymentMethod.PayOnDelivery, commissionUsesMerchantBase: true);

        Assert.Equal(4, money.Version);
        Assert.Equal(customerUnitPrice * 4, money.ProductSubtotal);
        Assert.Equal(2200m, money.TotalMerchantPayable);
        Assert.Equal(platformUnitShare * 4, money.TotalMerchantCommission);
        Assert.Equal(money.ProductSubtotal, money.TotalMerchantPayable + money.TotalMerchantCommission);
        Assert.Equal(money.ProductSubtotal + 200m, money.CashToCollect);
        Assert.Equal(money.CashToCollect, money.GrandTotal);
        Assert.Equal(75m, money.CaptainEarning);
        Assert.Equal(125m, money.PlatformDeliveryRevenue);
        Assert.Equal(money.TotalMerchantCommission + 125m, money.PlatformTotalRevenue);
        Assert.Equal(money.ProductSubtotal, invoice.GrossAmount);
        Assert.Equal(money.TotalMerchantPayable, invoice.MerchantPayable);
        Assert.Equal(money.TotalMerchantCommission, invoice.PlatformCommission);
    }

    [Fact]
    public void RejectedLinesDoNotCreateMerchantPayablesOrDriverCollection()
    {
        var details = new[] {
            new OrderDetail { MerchantId = 27, Quantity = 1, SingleMerchantProfit = 550m,
                SinglePrice = 605m, SingleFinalPrice = 556m, CommissionRatePercent = 10m,
                OrderDetailStatus = OrderDetailStatus.MerchantAccepted },
            new OrderDetail { MerchantId = 27, Quantity = 3, SingleMerchantProfit = 550m,
                SinglePrice = 605m, SingleFinalPrice = 556m, CommissionRatePercent = 10m,
                OrderDetailStatus = OrderDetailStatus.MerchantRejected }
        };
        var service = new OrderMoneyCalculationService();
        var money = service.CalculateOrderMoney(details, 200m, PaymentMethod.PayOnDelivery,
            commissionUsesMerchantBase: true);
        var invoice = service.CalculateMerchantBill(details, 10m, PaymentMethod.PayOnDelivery,
            commissionUsesMerchantBase: true);
        Assert.Equal(556m, money.ProductSubtotal);
        Assert.Equal(550m, money.TotalMerchantPayable);
        Assert.Equal(6m, money.TotalMerchantCommission);
        Assert.Equal(756m, money.CashToCollect);
        Assert.Equal(550m, invoice.MerchantPayable);
    }
}
