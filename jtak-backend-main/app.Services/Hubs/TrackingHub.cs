#nullable enable
using System;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using App.Orders.Data;
using App.Shared.Entities.Enums;
using Modules.Orders.Entities;

namespace App.Shared.Services.Hubs
{
    [Authorize]
    public class TrackingHub : Hub
    {
        private readonly OrdersDbContext _ordersDbContext;

        public TrackingHub(OrdersDbContext ordersDbContext)
        {
            _ordersDbContext = ordersDbContext;
        }

        public const string CourierDispatchGroup = "courier_dispatch";
        public const string FleetDispatchGroup = CourierDispatchGroup;

        [Authorize]
        public async Task JoinOrderTracking(int orderId)
        {
            if (orderId <= 0)
            {
                throw new HubException("Invalid order ID.");
            }

            var user = Context.User;
            if (user?.Identity?.IsAuthenticated != true)
            {
                throw new HubException("Unauthorized to track this order.");
            }

            // Admins can track any order
            if (user.IsInRole(nameof(AppRoleName.Admin)))
            {
                await Groups.AddToGroupAsync(Context.ConnectionId, $"order_{orderId}");
                return;
            }

            var userIdStr = user.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? user.FindFirst("sub")?.Value;
            if (!string.IsNullOrEmpty(userIdStr) && Guid.TryParse(userIdStr, out var userId))
            {
                var order = await _ordersDbContext.Set<Order>()
                    .AsNoTracking()
                    .FirstOrDefaultAsync(o => o.Id == orderId);

                if (order == null)
                {
                    throw new HubException("Order not found.");
                }

                if (order.UserId != userId && order.DeliveryId != userId)
                {
                    throw new HubException("Unauthorized to track this order.");
                }
            }

            await Groups.AddToGroupAsync(Context.ConnectionId, $"order_{orderId}");
        }

        [Authorize]
        public async Task LeaveOrderTracking(int orderId)
        {
            await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"order_{orderId}");
        }

        [Authorize(Policy = nameof(AppPermissionKey.AdminPermission))]
        public async Task JoinCourierRadar()
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, CourierDispatchGroup);
        }

        [Authorize(Policy = nameof(AppPermissionKey.AdminPermission))]
        public async Task LeaveCourierRadar()
        {
            await Groups.RemoveFromGroupAsync(Context.ConnectionId, CourierDispatchGroup);
        }

        [Authorize(Policy = nameof(AppPermissionKey.AdminPermission))]
        public async Task JoinFleetRadar() => await JoinCourierRadar();

        [Authorize(Policy = nameof(AppPermissionKey.AdminPermission))]
        public async Task LeaveFleetRadar() => await LeaveCourierRadar();

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            await base.OnDisconnectedAsync(exception);
        }
    }
}
