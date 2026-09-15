namespace Modules.Accounting.Entities
{
    public enum AccountType
    {
        Asset = 1,       // Normal Balance: Debit (e.g., Captain Cash Float, Bank, Vault)
        Liability = 2,   // Normal Balance: Credit (e.g., Vendor Payable, Captain Earnings Payable)
        Equity = 3,      // Normal Balance: Credit (e.g., Capital, Retained Earnings)
        Revenue = 4,     // Normal Balance: Credit (e.g., Platform Commission, Delivery Markup)
        Expense = 5      // Normal Balance: Debit (e.g., Operational Costs, Driver Subsidies)
    }
}
