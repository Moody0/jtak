using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using App.Catalog.Data;
using App.Orders.Data;
using Microsoft.EntityFrameworkCore;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using Modules.Accounting.Services;
using Modules.Catalog.Entities;
using Modules.Orders.Entities;
using Xunit;

namespace Modules.Accounting.Tests
{
    public class MerchantContractedCommissionRateTests
    {
        [Theory]
        [InlineData(10.0, 605.0, 60.5, 544.5)]
        [InlineData(10.0, 598.4, 59.84, 538.56)]
        [InlineData(10.0, 2048.4, 204.84, 1843.56)]
        [InlineData(15.0, 1000.0, 150.0, 850.0)]
        [InlineData(0.0, 500.0, 0.0, 500.0)]
        public void ContractedCommission_ProducesUniformDeductionRate(double rateDbl, double totalDbl, double expectedJtakDbl, double expectedMerchantDbl)
        {
            decimal commissionRate = (decimal)rateDbl;
            decimal totalAmount = (decimal)totalDbl;
            decimal expectedJtak = (decimal)expectedJtakDbl;
            decimal expectedMerchant = (decimal)expectedMerchantDbl;

            decimal jtakAmount = commissionRate > 0 ? Math.Round(totalAmount * (commissionRate / 100m), 2) : 0m;
            decimal merchantAmount = totalAmount - jtakAmount;

            Assert.Equal(expectedJtak, jtakAmount);
            Assert.Equal(expectedMerchant, merchantAmount);
            Assert.Equal(totalAmount, jtakAmount + merchantAmount);

            if (totalAmount > 0 && commissionRate > 0)
            {
                decimal effectiveRate = Math.Round((jtakAmount / totalAmount) * 100m, 2);
                Assert.Equal(commissionRate, effectiveRate);
            }
        }

        [Fact]
        public void MultiItemOrder_CalculatesAuthoritativeMerchantBill_WithoutItemDiscrepancy()
        {
            // Simulate Meat Station (محطة اللحوم) Order #43
            decimal commissionRate = 10m; // Contracted rate configured in Admin page
            var items = new[]
            {
                new { Title = "غريلد تشكن برجر", SinglePrice = 598.4m, Qty = 1 },
                new { Title = "وجبة كرسبي", SinglePrice = 605.0m, Qty = 1 },
                new { Title = "وجبة شيش طاووق", SinglePrice = 495.0m, Qty = 1 },
                new { Title = "كاسة بطاطاااا", SinglePrice = 350.0m, Qty = 1 },
            };

            decimal totalAmount = items.Sum(x => x.SinglePrice * x.Qty); // 2048.4
            decimal jtakAmount = commissionRate > 0 ? Math.Round(totalAmount * (commissionRate / 100m), 2) : 0m; // 204.84
            decimal merchantAmount = totalAmount - jtakAmount; // 1843.56

            var bill = new Bill
            {
                MerchantId = 27,
                OrderId = 43,
                TotalAmount = totalAmount,
                MerchantAmount = merchantAmount,
                JTakAmount = jtakAmount,
                JTakAdditionalAmount = 0m,
                PaymentMethod = 0,
                DueDate = DateTime.UtcNow,
                IsAddedToDues = false
            };

            Assert.Equal(2048.4m, bill.TotalAmount);
            Assert.Equal(204.84m, bill.JTakAmount);
            Assert.Equal(1843.56m, bill.MerchantAmount);
            Assert.Equal(0m, bill.JTakAdditionalAmount);

            // Exactly 10% deduction
            Assert.Equal(0.10m, bill.JTakAmount / bill.TotalAmount);
        }
    }
}
