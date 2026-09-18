namespace Modules.Orders.Entities
{
    public class AdminOrdersSummaryDto
    {
        public int Total { get; set; }
        public int PendingApproval { get; set; }
        public int WithoutDriver { get; set; }
        public int ReadyForDelivery { get; set; }
        public int InDelivery { get; set; }
        public int Completed { get; set; }
        public int CancelledRejected { get; set; }
    }
}
