namespace Modules.Catalog.Entities
{
    /// <summary>
    /// The USD to local-currency rate the administrator maintains from the
    /// dashboard. It is persisted under its own language-neutral settings key
    /// rather than inside the localized settings blob, so that every request
    /// resolves the same rate no matter which culture it runs under.
    /// </summary>
    public class UsdExchangeRateSetting
    {
        /// <summary>
        /// Settings key holding this value. Shared so the API layer that writes
        /// the rate and the catalog services that price against it cannot drift
        /// apart.
        /// </summary>
        public const string Key = "UsdToSypExchangeRate";

        public decimal Rate { get; set; }
    }
}
