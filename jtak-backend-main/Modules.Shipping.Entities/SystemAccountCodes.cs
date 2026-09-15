namespace Modules.Accounting.Entities
{
    public static class SystemAccountCodes
    {
        // Assets (1xxx)
        public const string CompanyMainVault = "1000";
        public const string CompanyCashSafe = "1010-CASH-SAFE";
        public const string BankMain = "1020-BANK-MAIN";
        public const string CaptainCashFloatPrefix = "1010-CAP-";
        public const string ElectronicPaymentGateway = "1030-PGW-CLEARING";

        // Liabilities (2xxx)
        public const string VendorPayablePrefix = "2010-VND-";
        public const string CaptainEarningsPrefix = "2020-CAP-";
        public const string CustomerWalletPrefix = "2030-CUST-";

        // Revenue (4xxx)
        public const string PlatformCommissionRevenue = "4010";
        public const string PlatformDeliveryFeeRevenue = "4020";
        public const string CashOverageRevenue = "4030";
        public const string JtakMarketSalesRevenue = "4040";

        // Expense (5xxx)
        public const string OperationalExpense = "5010";
        public const string PromotionalDiscountExpense = "5020";
        public const string CashShortageExpense = "5030";
    }
}
