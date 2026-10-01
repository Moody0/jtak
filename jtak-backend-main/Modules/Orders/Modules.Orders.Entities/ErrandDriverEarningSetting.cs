namespace Modules.Orders.Entities
{
    /// <summary>Fixed driver earning for a single "طلب أي شيء" errand.</summary>
    public sealed class ErrandDriverEarningSetting
    {
        public const string Key = "ErrandDriverEarningSetting";

        // Deliberately unconfigured by default: admins must choose this wage
        // before sending customer quotes, avoiding an accidental guessed payout.
        public decimal Amount { get; set; }

        public bool IsValid => Amount > 0m && Amount <= 1000000000m &&
            decimal.Round(Amount, 2) == Amount;
    }
}
