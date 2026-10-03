using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Modules.Accounting.Entities;

namespace Modules.Accounting.Services;

/// <summary>Posts collection and immediate errand wage payment atomically.</summary>
public static class ErrandDeliveryPosting
{
    public const string ReferenceType = "ErrandDelivery";

    public static async Task<JournalTransactionDto> PostAsync(ILedgerService ledger, int requestId,
        Guid driverId, decimal itemPrice, decimal deliveryFee, decimal purchaseCost, decimal driverEarning)
    {
        if (itemPrice < 0m || deliveryFee < 0m || purchaseCost < 0m || purchaseCost > itemPrice || driverEarning < 0m)
            throw new ArgumentOutOfRangeException(nameof(itemPrice), "قيم تسوية الطلب غير صالحة.");
        var total = itemPrice + deliveryFee;
        // Retain the wage from this collection only. An exceptional wage above
        // all collected cash leaves the uncovered portion payable, not negative custody.
        var paidEarning = Math.Min(total, driverEarning);
        var custodyCash = total - paidEarning;
        var cash = await ledger.GetOrCreateUserAccountAsync(driverId, AccountType.Asset,
            SystemAccountCodes.CaptainCashFloatPrefix, "Cash Float - Errand Driver");
        var goods = await ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.ErrandGoodsInTransit,
            "Errand Goods In Transit", AccountType.Asset);
        var earnings = await ledger.GetOrCreateUserAccountAsync(driverId, AccountType.Liability,
            SystemAccountCodes.CaptainEarningsPrefix, "Errand Driver Earnings");
        var entries = new List<PostLedgerEntryRequest>();
        if (custodyCash > 0m)
            entries.Add(new() { AccountId = cash.Id, Debit = custodyCash,
                Memo = $"Errand #{requestId} company cash after driver retained wage {paidEarning}" });
        if (purchaseCost > 0m)
            entries.Add(new() { AccountId = goods.Id, Credit = purchaseCost,
                Memo = $"Errand #{requestId} goods delivered" });
        var margin = itemPrice - purchaseCost;
        if (margin > 0m)
        {
            var revenue = await ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.ErrandProductMarginRevenue,
                "Errand Product Margin Revenue", AccountType.Revenue);
            entries.Add(new() { AccountId = revenue.Id, Credit = margin,
                Memo = $"Errand #{requestId} contracted shop discount" });
        }
        if (driverEarning > 0m)
            entries.Add(new() { AccountId = earnings.Id, Credit = driverEarning,
                Memo = $"Errand #{requestId} driver delivery earning" });
        if (paidEarning > 0m)
            entries.Add(new() { AccountId = earnings.Id, Debit = paidEarning,
                Memo = $"Errand #{requestId} wage paid immediately from collected cash" });
        var feeDifference = deliveryFee - driverEarning;
        if (feeDifference > 0m)
        {
            var feeRevenue = await ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.ErrandDeliveryFeeRevenue,
                "Errand Delivery Fee Revenue", AccountType.Revenue);
            entries.Add(new() { AccountId = feeRevenue.Id, Credit = feeDifference,
                Memo = $"Errand #{requestId} delivery fee retained by platform" });
        }
        else if (feeDifference < 0m)
        {
            var subsidy = await ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.DriverEarningSubsidyExpense,
                "Driver Earning Subsidy Expense", AccountType.Expense);
            entries.Add(new() { AccountId = subsidy.Id, Debit = -feeDifference,
                Memo = $"Errand #{requestId} driver wage subsidy" });
        }
        return await ledger.PostTransactionAsync(new PostTransactionRequest
        {
            ReferenceType = ReferenceType, ReferenceId = requestId.ToString(),
            IdempotencyKey = $"ErrandDelivery-{requestId}",
            Description = $"Errand #{requestId} delivery with driver wage paid from collected cash",
            Entries = entries
        });
    }
}
