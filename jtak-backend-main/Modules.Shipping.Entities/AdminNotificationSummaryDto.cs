using System;

namespace Modules.Accounting.Entities
{
    public class AdminNotificationSummaryDto
    {
        public int Orders { get; set; }
        public int SupportMessages { get; set; }
        public int DriverSettlements { get; set; }
        public int MerchantSettlements { get; set; }
        public int Reconciliation { get; set; }
        public int Users { get; set; }
        public int TotalActionable { get; set; }
    }
}
