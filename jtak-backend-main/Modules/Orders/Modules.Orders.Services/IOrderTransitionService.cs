using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Modules.Orders.Entities;

namespace Modules.Orders.Services
{
    public class OrderTransitionResult
    {
        public int OrderId { get; set; }
        public int? MerchantId { get; set; }
        public OrderDetailStatus TargetStatus { get; set; }
        public bool Success { get; set; }
        public bool IsNoOp { get; set; }
        public int AffectedItemsCount { get; set; }
        public string Message { get; set; }
        public List<OrderDetailDto> AffectedDetails { get; set; } = new();
    }

    public interface IOrderTransitionService
    {
        bool CanTransition(OrderDetailStatus from, OrderDetailStatus to);
        Task<OrderTransitionResult> TransitionOrderDetailAsync(int orderId, int orderDetailId, OrderDetailStatus targetStatus, string reason = null, Guid? actorId = null);
        Task<OrderTransitionResult> TransitionMerchantOrderAsync(int orderId, int merchantId, OrderDetailStatus targetStatus, string reason = null, Guid? actorId = null);
        Task<OrderTransitionResult> TransitionFullOrderAsync(int orderId, OrderDetailStatus targetStatus, string reason = null, Guid? actorId = null);
    }
}
