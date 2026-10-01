using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using App.Orders.Data;
using App.Shared.Data.MultiContext;
using Microsoft.EntityFrameworkCore;
using Modules.Orders.Entities;

namespace Modules.Orders.Services
{
    public class OrderTransitionService : IOrderTransitionService
    {
        private readonly IOrdersUnitOfWork _uow;
        private readonly ITrackableRepository<Order, OrdersDbContext> _orderRepo;
        private readonly ITrackableRepository<OrderDetail, OrdersDbContext> _orderDetailRepo;
        private readonly ITrackableRepository<OrderStatusChangeLog, OrdersDbContext> _logRepo;

        public OrderTransitionService(
            IOrdersUnitOfWork uow,
            ITrackableRepository<Order, OrdersDbContext> orderRepo,
            ITrackableRepository<OrderDetail, OrdersDbContext> orderDetailRepo,
            ITrackableRepository<OrderStatusChangeLog, OrdersDbContext> logRepo)
        {
            _uow = uow;
            _orderRepo = orderRepo;
            _orderDetailRepo = orderDetailRepo;
            _logRepo = logRepo;
        }

        public bool CanTransition(OrderDetailStatus from, OrderDetailStatus to)
        {
            if (from == to) return true;

            return from switch
            {
                OrderDetailStatus.Pending => to switch
                {
                    OrderDetailStatus.MerchantAccepted => true,
                    OrderDetailStatus.MerchantRejected => true,
                    OrderDetailStatus.CustomerCanceled => true,
                    OrderDetailStatus.DeliveryCanceled => true,
                    _ => false
                },
                OrderDetailStatus.CustomerPending => to switch
                {
                    OrderDetailStatus.Pending => true,
                    OrderDetailStatus.MerchantAccepted => true,
                    OrderDetailStatus.MerchantRejected => true,
                    OrderDetailStatus.CustomerCanceled => true,
                    _ => false
                },
                OrderDetailStatus.MerchantAccepted => to switch
                {
                    OrderDetailStatus.ReadyForPickup => true,
                    OrderDetailStatus.MerchantRejected => true,
                    OrderDetailStatus.CustomerCanceled => true,
                    OrderDetailStatus.DeliveryCanceled => true,
                    _ => false
                },
                OrderDetailStatus.ReadyForPickup => to switch
                {
                    OrderDetailStatus.ShippingStarted => true,
                    OrderDetailStatus.DeliveryCanceled => true,
                    OrderDetailStatus.CustomerCanceled => true,
                    _ => false
                },
                OrderDetailStatus.ShippingStarted => to switch
                {
                    OrderDetailStatus.Delivered => true,
                    OrderDetailStatus.ReadyForPickup => true, // Driver reassignment or decline
                    OrderDetailStatus.DeliveryCanceled => true,
                    _ => false
                },
                OrderDetailStatus.Delivered => false,
                OrderDetailStatus.MerchantRejected => false,
                OrderDetailStatus.CustomerCanceled => false,
                OrderDetailStatus.DeliveryCanceled => false,
                _ => false
            };
        }

        public async Task<OrderTransitionResult> TransitionOrderDetailAsync(
            int orderId,
            int orderDetailId,
            OrderDetailStatus targetStatus,
            string reason = null,
            Guid? actorId = null)
        {
            var detail = await _orderDetailRepo.Queryable()
                .FirstOrDefaultAsync(d => d.Id == orderDetailId && d.OrderId == orderId);

            if (detail == null)
            {
                throw new KeyNotFoundException($"Order detail #{orderDetailId} not found in order #{orderId}.");
            }

            if (detail.OrderDetailStatus == targetStatus)
            {
                // Idempotent retry: already at target status
                return new OrderTransitionResult
                {
                    OrderId = orderId,
                    MerchantId = detail.MerchantId,
                    TargetStatus = targetStatus,
                    Success = true,
                    IsNoOp = true,
                    AffectedItemsCount = 0,
                    Message = $"Item #{orderDetailId} is already in state {targetStatus}.",
                    AffectedDetails = new List<OrderDetailDto> { detail.ToDto() }
                };
            }

            if (!CanTransition(detail.OrderDetailStatus, targetStatus))
            {
                throw new InvalidOperationException(
                    $"Cannot transition order #{orderId} item #{orderDetailId} from {detail.OrderDetailStatus} to {targetStatus}.");
            }

            detail.OrderDetailStatus = targetStatus;
            if (!string.IsNullOrWhiteSpace(reason))
            {
                detail.Warning = reason.Trim();
            }

            _logRepo.Insert(new OrderStatusChangeLog
            {
                OrderId = orderId,
                OrderDetailStatus = targetStatus,
                OrdreDetails = JsonSerializer.Serialize(new[] { detail.ToDto() }),
                DriverId = actorId
            });

            await _uow.SaveChangesAsync();

            return new OrderTransitionResult
            {
                OrderId = orderId,
                MerchantId = detail.MerchantId,
                TargetStatus = targetStatus,
                Success = true,
                IsNoOp = false,
                AffectedItemsCount = 1,
                Message = $"Successfully transitioned item #{orderDetailId} to {targetStatus}.",
                AffectedDetails = new List<OrderDetailDto> { detail.ToDto() }
            };
        }

        public async Task<OrderTransitionResult> TransitionMerchantOrderAsync(
            int orderId,
            int merchantId,
            OrderDetailStatus targetStatus,
            string reason = null,
            Guid? actorId = null)
        {
            var details = await _orderDetailRepo.Queryable()
                .Where(d => d.OrderId == orderId && d.MerchantId == merchantId)
                .ToListAsync();

            if (!details.Any())
            {
                throw new KeyNotFoundException($"No items found for merchant #{merchantId} in order #{orderId}.");
            }

            var toUpdate = new List<OrderDetail>();
            foreach (var d in details)
            {
                if (d.OrderDetailStatus == targetStatus)
                {
                    continue; // already in target status, idempotent
                }

                if (!CanTransition(d.OrderDetailStatus, targetStatus))
                {
                    throw new InvalidOperationException(
                        $"Cannot transition item #{d.Id} from {d.OrderDetailStatus} to {targetStatus} for merchant #{merchantId}.");
                }

                d.OrderDetailStatus = targetStatus;
                if (!string.IsNullOrWhiteSpace(reason))
                {
                    d.Warning = reason.Trim();
                }
                toUpdate.Add(d);
            }

            if (!toUpdate.Any())
            {
                return new OrderTransitionResult
                {
                    OrderId = orderId,
                    MerchantId = merchantId,
                    TargetStatus = targetStatus,
                    Success = true,
                    IsNoOp = true,
                    AffectedItemsCount = 0,
                    Message = $"All items for merchant #{merchantId} in order #{orderId} are already in status {targetStatus}.",
                    AffectedDetails = details.Select(x => x.ToDto()).ToList()
                };
            }

            _logRepo.Insert(new OrderStatusChangeLog
            {
                OrderId = orderId,
                OrderDetailStatus = targetStatus,
                OrdreDetails = JsonSerializer.Serialize(toUpdate.Select(x => x.ToDto())),
                DriverId = actorId
            });

            await _uow.SaveChangesAsync();

            return new OrderTransitionResult
            {
                OrderId = orderId,
                MerchantId = merchantId,
                TargetStatus = targetStatus,
                Success = true,
                IsNoOp = false,
                AffectedItemsCount = toUpdate.Count,
                Message = $"Successfully transitioned {toUpdate.Count} items to {targetStatus}.",
                AffectedDetails = toUpdate.Select(x => x.ToDto()).ToList()
            };
        }

        public async Task<OrderTransitionResult> TransitionFullOrderAsync(
            int orderId,
            OrderDetailStatus targetStatus,
            string reason = null,
            Guid? actorId = null)
        {
            var details = await _orderDetailRepo.Queryable()
                .Where(d => d.OrderId == orderId)
                .ToListAsync();

            if (!details.Any())
            {
                throw new KeyNotFoundException($"No items found in order #{orderId}.");
            }

            var toUpdate = new List<OrderDetail>();
            foreach (var d in details)
            {
                if (d.OrderDetailStatus == targetStatus)
                {
                    continue;
                }

                if (!CanTransition(d.OrderDetailStatus, targetStatus))
                {
                    throw new InvalidOperationException(
                        $"Cannot transition item #{d.Id} from {d.OrderDetailStatus} to {targetStatus}.");
                }

                d.OrderDetailStatus = targetStatus;
                if (!string.IsNullOrWhiteSpace(reason))
                {
                    d.Warning = reason.Trim();
                }
                toUpdate.Add(d);
            }

            if (!toUpdate.Any())
            {
                return new OrderTransitionResult
                {
                    OrderId = orderId,
                    TargetStatus = targetStatus,
                    Success = true,
                    IsNoOp = true,
                    AffectedItemsCount = 0,
                    Message = $"All items in order #{orderId} are already in status {targetStatus}.",
                    AffectedDetails = details.Select(x => x.ToDto()).ToList()
                };
            }

            _logRepo.Insert(new OrderStatusChangeLog
            {
                OrderId = orderId,
                OrderDetailStatus = targetStatus,
                OrdreDetails = JsonSerializer.Serialize(toUpdate.Select(x => x.ToDto())),
                DriverId = actorId
            });

            await _uow.SaveChangesAsync();

            return new OrderTransitionResult
            {
                OrderId = orderId,
                TargetStatus = targetStatus,
                Success = true,
                IsNoOp = false,
                AffectedItemsCount = toUpdate.Count,
                Message = $"Successfully transitioned {toUpdate.Count} items in order #{orderId} to {targetStatus}.",
                AffectedDetails = toUpdate.Select(x => x.ToDto()).ToList()
            };
        }
    }
}
