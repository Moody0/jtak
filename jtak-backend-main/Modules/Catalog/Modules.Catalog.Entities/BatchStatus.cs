namespace Modules.Catalog.Entities
{
    public enum BatchStatus
    {
        Active = 0,
        NearExpiry = 1,
        Expired = 2,
        Quarantined = 3,
        Depleted = 4
    }
}
