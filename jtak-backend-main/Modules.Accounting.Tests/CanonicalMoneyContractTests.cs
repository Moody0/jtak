using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using App.Shared.Entities.Enums;
using App.Shared.Services.Pricing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using Modules.Accounting.Services;
using Modules.Orders.Entities;
using Modules.Catalog.Entities;
using Modules.Shipping.Entities;
using Modules.Shipping.Services;
using Xunit;
using PaymentMethod = Modules.Orders.Entities.PaymentMethod;

namespace Modules.Accounting.Tests
{
    public class CanonicalMoneyContractTests
    {
        private readonly IOrderMoneyCalculationService _calcService = new OrderMoneyCalculationService();

        [Fact]
        public void MerchantQuotedPrice_AddsConfiguredMarkupOnce_AndPaysMerchantTheQuote()
        {
            var product = new MerchantProductDto
            {
                MerchantId = 27,
                MerchantPrice = 598m,
                ProfitOutOfMerchantPricePercent = 10m
            };
            Assert.Equal(658m, product.FinalPrice); // 59.8 SYP rounds to 60
            Assert.Equal(598m, product.MerchantProfit);

            var details = new[]
            {
                new OrderDetailDto
                {
                    MerchantId = 27,
                    Quantity = 2,
                    SingleFinalPrice = product.FinalPrice,
                    SingleMerchantProfit = product.MerchantProfit,
                    OrderDetailStatus = OrderDetailStatus.Pending
                }
            };
            var contracts = new[] { new MerchantCommissionInfo { MerchantId = 27, CommissionRatePercent = 10m } };
            var money = _calcService.CalculateOrderMoney(details, 0m, PaymentMethod.PayOnDelivery,
                merchantCommissionInfos: contracts, commissionIsMarkup: true);
            Assert.Equal(2, money.Version);
            Assert.Equal(1316m, money.ProductSubtotal);
            Assert.Equal(120m, money.TotalMerchantCommission);
            Assert.Equal(1196m, money.TotalMerchantPayable);

            var bill = _calcService.CalculateMerchantBill(new[]
            {
                new OrderDetail
                {
                    MerchantId = 27,
                    Quantity = 2,
                    SingleFinalPrice = product.FinalPrice,
                    SingleMerchantProfit = product.MerchantProfit,
                    OrderDetailStatus = OrderDetailStatus.Pending
                }
            }, 10m, PaymentMethod.PayOnDelivery, commissionIsMarkup: true);
            Assert.Equal(money.TotalMerchantCommission, bill.PlatformCommission);
            Assert.Equal(money.TotalMerchantPayable, bill.MerchantPayable);
        }

        [Fact]
        public void ContractCommissionIsTenPercentOfBilledGrossAndPreservesHalfLira()
        {
            var details = new[]
            {
                new OrderDetailDto
                {
                    MerchantId = 27,
                    Quantity = 1,
                    SingleFinalPrice = 2725m,
                    SingleMerchantProfit = 2500m,
                    OrderDetailStatus = OrderDetailStatus.Pending
                }
            };
            var contracts = new[]
            {
                new MerchantCommissionInfo { MerchantId = 27, CommissionRatePercent = 10m }
            };

            var money = _calcService.CalculateOrderMoney(
                details,
                deliveryFee: 225m,
                paymentMethod: PaymentMethod.PayOnDelivery,
                merchantCommissionInfos: contracts,
                commissionIsMarkup: true,
                commissionIsPercentageOfGross: true);

            var split = Assert.Single(money.MerchantSplits);
            Assert.Equal(3, money.Version);
            Assert.Equal(272.5m, split.MerchantCommission);
            Assert.Equal(2452.5m, split.MerchantPayable);
            Assert.Equal(272.5m, money.TotalMerchantCommission);
            Assert.Equal(2, money.CurrencyPrecision);

            var bill = _calcService.CalculateMerchantBill(
                new[]
                {
                    new OrderDetail
                    {
                        MerchantId = 27,
                        Quantity = 1,
                        SingleFinalPrice = 2725m,
                        SingleMerchantProfit = 2500m,
                        OrderDetailStatus = OrderDetailStatus.Pending
                    }
                },
                10m,
                PaymentMethod.PayOnDelivery,
                commissionIsMarkup: true,
                commissionIsPercentageOfGross: true);
            Assert.Equal(272.5m, bill.PlatformCommission);
            Assert.Equal(2452.5m, bill.MerchantPayable);
        }

        [Fact]
        public void MerchantMarkup_UsesStoreSpecificFractionalRate_NotHardcodedTenPercent()
        {
            var product = new MerchantProductDto
            {
                MerchantPrice = 495m,
                ProfitOutOfMerchantPricePercent = 12.5m
            };
            Assert.Equal(62m, product.ProfitOutOfMerchantPrice);
            Assert.Equal(557m, product.FinalPrice);
            Assert.Equal(495m, product.MerchantProfit);
        }

        [Fact]
        public void PlatformOwnedStore_DoesNotCreateMerchantPayable_InMarkupOrders()
        {
            var detail = new OrderDetailDto
            {
                MerchantId = 1,
                Quantity = 1,
                SingleFinalPrice = 658m,
                SingleMerchantProfit = 598m,
                IsPlatformOwnedSnapshot = true,
                OrderDetailStatus = OrderDetailStatus.Pending
            };
            var money = _calcService.CalculateOrderMoney(new[] { detail }, 0m, PaymentMethod.PayOnDelivery,
                merchantCommissionInfos: new[] { new MerchantCommissionInfo { MerchantId = 1, IsDarkStore = true } },
                commissionIsMarkup: true);
            Assert.Equal(0m, money.TotalMerchantPayable);
            Assert.Equal(658m, money.TotalMerchantCommission);
        }

        [Fact]
        public void PriceWithAndWithoutCompareAtDiscount_UsesOnlyUnitSalePriceForTotals()
        {
            // Item 1: Discounted (CompareAt = 30,000, SalePrice = 24,000, Qty = 2)
            // Item 2: Regular (SinglePrice = 15,000, SingleFinalPrice = 0, Qty = 1)
            var details = new List<OrderDetailDto>
            {
                new OrderDetailDto
                {
                    Id = 1,
                    ProductId = 101,
                    MerchantId = 1,
                    Quantity = 2,
                    SinglePrice = 30000m,
                    SingleFinalPrice = 24000m,
                    OrderDetailStatus = OrderDetailStatus.Pending
                },
                new OrderDetailDto
                {
                    Id = 2,
                    ProductId = 102,
                    MerchantId = 1,
                    Quantity = 1,
                    SinglePrice = 15000m,
                    SingleFinalPrice = 0m,
                    OrderDetailStatus = OrderDetailStatus.Pending
                }
            };

            // OrderDetailDto property checks
            Assert.Equal(30000m, details[0].CompareAtPrice);
            Assert.Equal(24000m, details[0].UnitSalePrice);
            Assert.Equal(48000m, details[0].TotalPrice);
            Assert.Equal(48000m, details[0].TotalFinalPrice);
            Assert.Equal(60000m, details[0].TotalCompareAtPrice);

            Assert.Equal(15000m, details[1].CompareAtPrice);
            Assert.Equal(15000m, details[1].UnitSalePrice);
            Assert.Equal(15000m, details[1].TotalPrice);

            // Calculation service checks
            var money = _calcService.CalculateOrderMoney(
                details,
                deliveryFee: 5000m,
                paymentMethod: PaymentMethod.PayOnDelivery);

            // Subtotal must be (2 * 24000) + (1 * 15000) = 63,000 (NOT 75,000 from CompareAt!)
            Assert.Equal(63000m, money.ProductSubtotal);
            Assert.Equal(5000m, money.DeliveryFee);
            Assert.Equal(68000m, money.GrandTotal);
            Assert.Equal(68000m, money.CashToCollect);
        }

        [Fact]
        public void SingleAndMultiMerchantSplits_BalancesExactlyToGross()
        {
            var details = new List<OrderDetailDto>
            {
                // Merchant 10: 2 items @ 20,000 = 40,000
                new OrderDetailDto
                {
                    Id = 1,
                    MerchantId = 10,
                    MerchantTitle = "Pizza Store",
                    Quantity = 2,
                    SingleFinalPrice = 20000m,
                    OrderDetailStatus = OrderDetailStatus.Pending
                },
                // Merchant 20: 3 items @ 10,000 = 30,000
                new OrderDetailDto
                {
                    Id = 2,
                    MerchantId = 20,
                    MerchantTitle = "Sweet Shop",
                    Quantity = 3,
                    SingleFinalPrice = 10000m,
                    OrderDetailStatus = OrderDetailStatus.Pending
                }
            };

            var commissions = new List<MerchantCommissionInfo>
            {
                new MerchantCommissionInfo { MerchantId = 10, CommissionRatePercent = 10m },
                new MerchantCommissionInfo { MerchantId = 20, CommissionRatePercent = 15m }
            };

            var money = _calcService.CalculateOrderMoney(
                details,
                deliveryFee: 8000m,
                paymentMethod: PaymentMethod.PayOnDelivery,
                merchantCommissionInfos: commissions,
                captainEarning: 6000m);

            Assert.Equal(70000m, money.ProductSubtotal);
            Assert.Equal(78000m, money.GrandTotal);
            Assert.Equal(78000m, money.CashToCollect);

            // Verify Merchant 10 split: Gross 40,000, Comm 4,000, Payable 36,000
            var split10 = money.MerchantSplits.First(s => s.MerchantId == 10);
            Assert.Equal(40000m, split10.MerchantGross);
            Assert.Equal(4000m, split10.MerchantCommission);
            Assert.Equal(36000m, split10.MerchantPayable);
            Assert.Equal(split10.MerchantGross, split10.MerchantCommission + split10.MerchantPayable);

            // Verify Merchant 20 split: Gross 30,000, Comm 4,500, Payable 25,500
            var split20 = money.MerchantSplits.First(s => s.MerchantId == 20);
            Assert.Equal(30000m, split20.MerchantGross);
            Assert.Equal(4500m, split20.MerchantCommission);
            Assert.Equal(25500m, split20.MerchantPayable);
            Assert.Equal(split20.MerchantGross, split20.MerchantCommission + split20.MerchantPayable);

            // Verify Totals
            Assert.Equal(70000m, money.TotalMerchantGross);
            Assert.Equal(8500m, money.TotalMerchantCommission);
            Assert.Equal(61500m, money.TotalMerchantPayable);
            Assert.Equal(money.TotalMerchantGross, money.TotalMerchantCommission + money.TotalMerchantPayable);

            // Verify Delivery split
            Assert.Equal(6000m, money.CaptainEarning);
            Assert.Equal(2000m, money.PlatformDeliveryRevenue);
            Assert.Equal(money.DeliveryFee, money.CaptainEarning + money.PlatformDeliveryRevenue);

            // Platform net revenue = commissions (8,500) + delivery margin (2,000) = 10,500
            Assert.Equal(10500m, money.PlatformTotalRevenue);
        }

        [Fact]
        public void PartialItemRejection_ExcludesRejectedAndCanceledItemsFromTotals()
        {
            var details = new List<OrderDetailDto>
            {
                new OrderDetailDto
                {
                    Id = 1,
                    Quantity = 2,
                    SingleFinalPrice = 10000m,
                    OrderDetailStatus = OrderDetailStatus.Pending // Active
                },
                new OrderDetailDto
                {
                    Id = 2,
                    Quantity = 1,
                    SingleFinalPrice = 25000m,
                    OrderDetailStatus = OrderDetailStatus.MerchantRejected // Rejected
                },
                new OrderDetailDto
                {
                    Id = 3,
                    Quantity = 3,
                    SingleFinalPrice = 5000m,
                    OrderDetailStatus = OrderDetailStatus.CustomerCanceled // Canceled
                },
                new OrderDetailDto
                {
                    Id = 4,
                    Quantity = 1,
                    SingleFinalPrice = 12000m,
                    OrderDetailStatus = OrderDetailStatus.DeliveryCanceled // Delivery Canceled
                }
            };

            var money = _calcService.CalculateOrderMoney(
                details,
                deliveryFee: 4000m,
                paymentMethod: PaymentMethod.PayOnDelivery);

            // Only item 1 (2 * 10,000 = 20,000) should be counted
            Assert.Equal(20000m, money.ProductSubtotal);
            Assert.Equal(24000m, money.GrandTotal);
            Assert.Equal(24000m, money.CashToCollect);
        }

        [Fact]
        public void CodVsElectronicPayment_CorrectlyDeterminesCashToCollect()
        {
            var details = new List<OrderDetailDto>
            {
                new OrderDetailDto { Id = 1, Quantity = 1, SingleFinalPrice = 50000m, OrderDetailStatus = OrderDetailStatus.Pending }
            };

            // Scenario A: COD with no prepayment
            var cod = _calcService.CalculateOrderMoney(details, 5000m, PaymentMethod.PayOnDelivery);
            Assert.Equal(55000m, cod.GrandTotal);
            Assert.Equal(55000m, cod.CashToCollect);
            Assert.True(cod.IsCod);

            // Scenario B: COD with partial deposit
            var codPartial = _calcService.CalculateOrderMoney(details, 5000m, PaymentMethod.PayOnDelivery, amountAlreadyPaid: 20000m);
            Assert.Equal(55000m, codPartial.GrandTotal);
            Assert.Equal(35000m, codPartial.CashToCollect);

            // Scenario C: Credit Card / Electronic payment
            var card = _calcService.CalculateOrderMoney(details, 5000m, PaymentMethod.CreditCardPayment);
            Assert.Equal(55000m, card.GrandTotal);
            Assert.Equal(0m, card.CashToCollect); // Zero cash collected from customer!
            Assert.False(card.IsCod);
        }

        [Fact]
        public void CurrencyRoundingBoundaries_SYPAwayFromZeroRounding()
        {
            // Odd decimal amounts under SYP currency
            decimal rounded1 = _calcService.RoundCurrency(1234.4m, "SYP");
            decimal rounded2 = _calcService.RoundCurrency(1234.5m, "SYP");
            decimal rounded3 = _calcService.RoundCurrency(1234.6m, "SYP");

            Assert.Equal(1234m, rounded1);
            Assert.Equal(1235m, rounded2);
            Assert.Equal(1235m, rounded3);

            // USD standard precision (2 decimals)
            decimal usd = _calcService.RoundCurrency(12.3456m, "USD");
            Assert.Equal(12.35m, usd);
        }

        [Fact]
        public async Task LedgerDebitsEqualCredits_UnderAllDeliveryScenarios()
        {
            var options = new DbContextOptionsBuilder<AccountingDbContext>()
                .UseInMemoryDatabase(databaseName: "CanonicalLedgerTests_" + Guid.NewGuid().ToString())
                .Options;

            using var context = new AccountingDbContext(options, null);
            var ledgerService = new LedgerService(context, NullLogger<LedgerService>.Instance);

            var captainId = Guid.NewGuid();

            // Scenario 1: Multi-merchant COD order with platform delivery fee
            var splitRequest = new OrderDeliveredSplitRequest
            {
                OrderId = 901,
                CaptainUserId = captainId,
                CaptainName = "Ahmad Driver",
                DeliveryFee = 6000m,
                DeliveryFeeIsPlatformRevenue = true,
                TotalsIncludeDeliveryFee = false,
                Currency = "SYP",
                IsCod = true,
                MerchantSplits = new List<MerchantSplitItem>
                {
                    new MerchantSplitItem
                    {
                        MerchantId = 51,
                        MerchantTitle = "Burger Joint",
                        TotalAmount = 30000m,
                        MerchantAmount = 27000m,
                        PlatformCommission = 3000m,
                        IsPlatformOwned = false
                    },
                    new MerchantSplitItem
                    {
                        MerchantId = 52,
                        MerchantTitle = "Juice Bar",
                        TotalAmount = 15000m,
                        MerchantAmount = 13500m,
                        PlatformCommission = 1500m,
                        IsPlatformOwned = false
                    }
                }
            };

            var txn = await ledgerService.PostOrderDeliveredSplitAsync(splitRequest);

            Assert.NotNull(txn);
            decimal totalDebits = txn.Entries.Sum(e => e.Debit);
            decimal totalCredits = txn.Entries.Sum(e => e.Credit);

            // Customer total: 30,000 + 15,000 + 6,000 = 51,000
            Assert.Equal(51000m, totalDebits);
            Assert.Equal(51000m, totalCredits);
            Assert.Equal(totalDebits, totalCredits);

            // Check captain float balance equals gross cash
            var captainFloat = await ledgerService.GetOrCreateUserAccountAsync(
                captainId, AccountType.Asset, SystemAccountCodes.CaptainCashFloatPrefix, "Float", "SYP");
            var floatBal = await ledgerService.GetAccountBalanceAsync(captainFloat.Id);
            Assert.Equal(51000m, floatBal);

            // Scenario 2: Electronic Payment (Non-COD)
            var nonCodRequest = new OrderDeliveredSplitRequest
            {
                OrderId = 902,
                CaptainUserId = captainId,
                CaptainName = "Ahmad Driver",
                DeliveryFee = 4000m,
                DeliveryFeeIsPlatformRevenue = true,
                TotalsIncludeDeliveryFee = false,
                Currency = "SYP",
                IsCod = false, // Online card payment
                MerchantSplits = new List<MerchantSplitItem>
                {
                    new MerchantSplitItem
                    {
                        MerchantId = 51,
                        MerchantTitle = "Burger Joint",
                        TotalAmount = 20000m,
                        MerchantAmount = 18000m,
                        PlatformCommission = 2000m,
                        IsPlatformOwned = false
                    }
                }
            };

            var txn2 = await ledgerService.PostOrderDeliveredSplitAsync(nonCodRequest);
            Assert.NotNull(txn2);
            decimal totalDebits2 = txn2.Entries.Sum(e => e.Debit);
            decimal totalCredits2 = txn2.Entries.Sum(e => e.Credit);

            Assert.Equal(24000m, totalDebits2);
            Assert.Equal(24000m, totalCredits2);
            Assert.Equal(totalDebits2, totalCredits2);

            // Electronic payment must debit the gateway account, NOT captain float
            var floatBalAfterNonCod = await ledgerService.GetAccountBalanceAsync(captainFloat.Id);
            Assert.Equal(51000m, floatBalAfterNonCod); // Unchanged!
        }
    }
}
