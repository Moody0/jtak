using System;

namespace Modules.Orders.Entities
{
    /// <summary>
    /// Durable order-domain event written in the same database transaction as
    /// the order. Delivery is at-least-once and guarded by a unique business key.
    /// </summary>
    public class OrderOutboxMessage
    {
        public const string MerchantNewOrder = "MerchantNewOrder";
        public const string AdminNewOrder = "AdminNewOrder";
        public const string AdminAcceptedMerchant = "AdminAcceptedMerchant";
        public const string AdminAcceptedAdmins = "AdminAcceptedAdmins";

        public long Id { get; set; }
        public string BusinessKey { get; set; }
        public string EventType { get; set; }
        public int OrderId { get; set; }
        public string Payload { get; set; }
        public DateTime OccurredAtUtc { get; set; }
        public DateTime? ProcessedAtUtc { get; set; }
        public DateTime? NextAttemptAtUtc { get; set; }
        public int AttemptCount { get; set; }
        public string LastError { get; set; }
        public Guid? LockId { get; set; }
        public DateTime? LockedUntilUtc { get; set; }
    }
}
