using App.ApiModels;
using App.Shared.Services;
using App.Shared.Services.eCommerce;
using AutoMapper;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Threading.Tasks;
using System.Globalization;
using OpenIddict.Validation.AspNetCore;
using Microsoft.AspNetCore.Authorization;
using System.Linq;
using App.Shared.Services.Extentions;
using App.Shared.Entities.Enums;
using Modules.Orders.Entities;
using App.Shared.Entities;
using Solf.Models;
using System;
using Modules.Catalog.Services;
using System.Collections.Generic;
using Modules.Orders.Services;
using App.Extensions;
using Modules.Shipping.Services;
using Modules.Accounting.Data;
using Modules.Accounting.Services;
using Modules.Accounting.Entities;
using Microsoft.Extensions.Logging;
using Modules.Shipping.Entities;
using App.Orders.Data;

using Microsoft.AspNetCore.SignalR;
using App.Shared.Services.Hubs;

namespace App.ApiControllers.V1.Admin
{
    [Route("api/v{version:apiVersion}/Admin/[controller]")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.AdminPermission))]
    public class OrdersController : SolApiController
    {
        //private readonly IAppUnitOfWork _uow;
        private readonly INotificationService _notificationService;
        private readonly UserManager<AppUser> _userManager;
        private readonly IMapper _mapper;
        private readonly IMerchantService _merchantService;
        private readonly IOrderService _service;
        private readonly IOrderDetailService _orderDetailService;
        private readonly IDeliveryService _deliveryService;
        private readonly IBillService _billService;
        private readonly IBalanceService _balanceService;
        private readonly ILedgerService _ledgerService;
        private readonly IInventoryBatchService _batchService;
        private readonly IOrdersUnitOfWork _ouow;
        private readonly IAccountingUnitOfWork _auow;
        private readonly IAdminAuditService _auditService;
        private readonly IHubContext<TrackingHub> _trackingHub;

        public OrdersController(INotificationService notificationService,
            UserManager<AppUser> userManager,
            IMerchantService merchantService,
            IDeliveryService deliveryService,
            IOrderService service,
            IOrderDetailService orderDetailService,
            IOrdersUnitOfWork ouow,
            IAccountingUnitOfWork auow,
            IBillService billService,
            IBalanceService balanceService,
            ILedgerService ledgerService,
            IInventoryBatchService batchService,
            ILogger<OrdersController> logger,
            IMapper mapper,
            IAdminAuditService auditService = null,
            IHubContext<TrackingHub> trackingHub = null)
        {
            _userManager = userManager;
            _notificationService = notificationService;
            _mapper = mapper;
            _merchantService = merchantService;
            _deliveryService = deliveryService;
            _service = service;
            _orderDetailService = orderDetailService;
            _billService = billService;
            _balanceService = balanceService;
            _ledgerService = ledgerService;
            _batchService = batchService;
            _auow = auow;
            _ouow = ouow;
            _auditService = auditService;
            _trackingHub = trackingHub;
        }

        /// <summary>
        /// Global orders summary counts for top status cards
        /// </summary>
        [HttpGet]
        [Route("Summary")]
        public async Task<ActionResult<AdminOrdersSummaryDto>> Summary()
        {
            var placedOrders = await _service.Queryable()
                .AsNoTracking()
                .Include(o => o.OrderDetails)
                .Where(o => o.OrderStatus == OrderStatus.Success && o.DeletionDate == null)
                .ToListAsync();

            int total = placedOrders.Count;
            int pendingApproval = 0;
            int withoutDriver = 0;
            int readyForDelivery = 0;
            int inDelivery = 0;
            int completed = 0;
            int cancelledRejected = 0;

            foreach (var order in placedOrders)
            {
                var details = order.OrderDetails ?? (ICollection<OrderDetail>)Array.Empty<OrderDetail>();
                bool allTerminal = details.Count > 0 && details.All(d =>
                    d.OrderDetailStatus == OrderDetailStatus.CustomerCanceled ||
                    d.OrderDetailStatus == OrderDetailStatus.DeliveryCanceled ||
                    d.OrderDetailStatus == OrderDetailStatus.MerchantRejected);

                if (allTerminal)
                {
                    cancelledRejected++;
                    continue;
                }

                var active = details.Where(d =>
                    d.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                    d.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled &&
                    d.OrderDetailStatus != OrderDetailStatus.MerchantRejected).ToList();

                bool isDelivered = order.DeliveredAt != null || (active.Count > 0 && active.All(d => d.OrderDetailStatus == OrderDetailStatus.Delivered));
                if (isDelivered)
                {
                    completed++;
                    continue;
                }

                bool hasAssignedDriver = order.DeliveryId.HasValue &&
                                         !string.IsNullOrWhiteSpace(order.DeliveryUser) &&
                                         !order.DeliveryUser.Contains("?");

                if (!hasAssignedDriver)
                {
                    withoutDriver++;
                }

                bool isReady = active.Count > 0 && active.All(d => d.OrderDetailStatus == OrderDetailStatus.ReadyForPickup);
                if (isReady)
                {
                    readyForDelivery++;
                }

                bool isInTransit = active.Any(d => d.OrderDetailStatus == OrderDetailStatus.ShippingStarted);
                if (isInTransit)
                {
                    inDelivery++;
                }

                bool isPending = !isReady && !isInTransit && (details.Count == 0 || active.Any(d =>
                    d.OrderDetailStatus == OrderDetailStatus.Pending ||
                    d.OrderDetailStatus == OrderDetailStatus.CustomerPending));
                if (isPending)
                {
                    pendingApproval++;
                }
            }

            return new AdminOrdersSummaryDto
            {
                Total = total,
                PendingApproval = pendingApproval,
                WithoutDriver = withoutDriver,
                ReadyForDelivery = readyForDelivery,
                InDelivery = inDelivery,
                Completed = completed,
                CancelledRejected = cancelledRejected
            };
        }

        /// <summary>
        /// Get a paged/filtered/ordered list of Orders
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Route("DataTable")]
        public async Task<ActionResult<TableResponseModel<OrderDto>>> DataTable([FromBody] MetronicTable request, [FromQuery] string status = null)
        {
            var isArchivedQuery = string.Equals(status?.Trim(), "ARCHIVED", StringComparison.OrdinalIgnoreCase);

            var query = _service.Queryable()
                .AsNoTracking()
                .Include(x => x.OrderDetails)
                .Where(x => x.OrderStatus == OrderStatus.Success);

            if (isArchivedQuery)
            {
                query = query.Where(o => o.DeletionDate != null);
            }
            else
            {
                query = query.Where(o => o.DeletionDate == null);

                // Server-side status filter
                if (!string.IsNullOrWhiteSpace(status))
                {
                    var norm = status.Trim().ToUpperInvariant();
                    switch (norm)
                    {
                        case "PENDING":
                        case "WAITING_APPROVAL":
                            query = query.Where(o => o.DeliveredAt == null &&
                                o.OrderDetails.Any(d => d.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                                                        d.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled &&
                                                        d.OrderDetailStatus != OrderDetailStatus.MerchantRejected) &&
                                !o.OrderDetails.Where(d => d.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                                                           d.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled &&
                                                           d.OrderDetailStatus != OrderDetailStatus.MerchantRejected)
                                               .All(d => d.OrderDetailStatus == OrderDetailStatus.Delivered) &&
                                !o.OrderDetails.Any(d => d.OrderDetailStatus == OrderDetailStatus.ShippingStarted) &&
                                !o.OrderDetails.Where(d => d.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                                                           d.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled &&
                                                           d.OrderDetailStatus != OrderDetailStatus.MerchantRejected)
                                               .All(d => d.OrderDetailStatus == OrderDetailStatus.ReadyForPickup) &&
                                (o.OrderDetails.Count == 0 || o.OrderDetails.Any(d => d.OrderDetailStatus == OrderDetailStatus.Pending ||
                                                                                      d.OrderDetailStatus == OrderDetailStatus.CustomerPending)));
                            break;

                        case "UNASSIGNED":
                        case "WITHOUT_DRIVER":
                            query = query.Where(o => o.DeliveredAt == null &&
                                (!o.DeliveryId.HasValue || string.IsNullOrEmpty(o.DeliveryUser) || o.DeliveryUser.Contains("?")) &&
                                o.OrderDetails.Any(d => d.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                                                        d.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled &&
                                                        d.OrderDetailStatus != OrderDetailStatus.MerchantRejected) &&
                                !o.OrderDetails.Where(d => d.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                                                           d.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled &&
                                                           d.OrderDetailStatus != OrderDetailStatus.MerchantRejected)
                                               .All(d => d.OrderDetailStatus == OrderDetailStatus.Delivered));
                            break;

                        case "READY":
                        case "READY_FOR_DELIVERY":
                            query = query.Where(o => o.DeliveredAt == null &&
                                !o.OrderDetails.Any(d => d.OrderDetailStatus == OrderDetailStatus.ShippingStarted) &&
                                o.OrderDetails.Any(d => d.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                                                        d.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled &&
                                                        d.OrderDetailStatus != OrderDetailStatus.MerchantRejected) &&
                                o.OrderDetails.Where(d => d.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                                                          d.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled &&
                                                          d.OrderDetailStatus != OrderDetailStatus.MerchantRejected)
                                              .All(d => d.OrderDetailStatus == OrderDetailStatus.ReadyForPickup));
                            break;

                        case "IN_TRANSIT":
                        case "IN_DELIVERY":
                            query = query.Where(o => o.DeliveredAt == null &&
                                o.OrderDetails.Any(d => d.OrderDetailStatus == OrderDetailStatus.ShippingStarted));
                            break;

                        case "DELIVERED":
                        case "COMPLETED":
                            query = query.Where(o => o.DeliveredAt != null ||
                                (o.OrderDetails.Any(d => d.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                                                         d.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled &&
                                                         d.OrderDetailStatus != OrderDetailStatus.MerchantRejected) &&
                                 o.OrderDetails.Where(d => d.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                                                           d.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled &&
                                                           d.OrderDetailStatus != OrderDetailStatus.MerchantRejected)
                                               .All(d => d.OrderDetailStatus == OrderDetailStatus.Delivered)));
                            break;

                        case "CANCELED":
                        case "CANCELLED":
                        case "REJECTED":
                            query = query.Where(o => o.OrderDetails.Count > 0 &&
                                o.OrderDetails.All(d => d.OrderDetailStatus == OrderDetailStatus.CustomerCanceled ||
                                                        d.OrderDetailStatus == OrderDetailStatus.DeliveryCanceled ||
                                                        d.OrderDetailStatus == OrderDetailStatus.MerchantRejected));
                            break;
                    }
                }
            }

            // Server-side search filter: strict ID, Customer Name, and Phone matching only
            if (!string.IsNullOrWhiteSpace(request?.Search))
            {
                var term = request.Search.Trim().ToLower();
                var isNumeric = int.TryParse(term.TrimStart('#'), out var searchId);
                if (isNumeric)
                {
                    query = query.Where(o => o.Id == searchId ||
                                             (o.Phonenumber != null && o.Phonenumber.Contains(term)) ||
                                             (o.User != null && o.User.ToLower().Contains(term)));
                }
                else
                {
                    query = query.Where(o => (o.Phonenumber != null && o.Phonenumber.Contains(term)) ||
                                             (o.User != null && o.User.ToLower().Contains(term)));
                }
            }

            var totalRecords = await query.CountAsync();

            // Server-side sorting
            var sortField = request?.SortField?.Trim()?.ToLower();
            var sortAsc = string.Equals(request?.SortOrder, "ASC", StringComparison.OrdinalIgnoreCase);

            query = sortField switch
            {
                "id" => sortAsc ? query.OrderBy(x => x.Id) : query.OrderByDescending(x => x.Id),
                "purchasedate" => sortAsc ? query.OrderBy(x => x.PurchaseDate) : query.OrderByDescending(x => x.PurchaseDate),
                "createddate" => sortAsc ? query.OrderBy(x => x.CreatedDate) : query.OrderByDescending(x => x.CreatedDate),
                _ => query.OrderByDescending(x => x.CreatedDate).ThenByDescending(x => x.Id)
            };

            // Server-side pagination
            var pageNumber = Math.Max(request?.PageNumber ?? 1, 1);
            var pageSize = Math.Max(request?.PageSize ?? 10, 1);
            var pagedOrders = await query.Skip((pageNumber - 1) * pageSize).Take(pageSize).ToListAsync();

            var dtoList = pagedOrders.Select(x => new OrderDto
            {
                Id = x.Id,
                UserId = x.UserId,
                DeliveryId = x.DeliveryId,
                DeliveryUser = x.DeliveryUser,
                DeliveryLat = x.DeliveryLat,
                DeliveryLng = x.DeliveryLng,
                DeliveryLocationUpdatedAt = x.DeliveryLocationUpdatedAt,
                Description = x.Description,
                Phonenumber = x.Phonenumber,
                OrderStatus = x.OrderStatus,
                PurchaseDate = x.PurchaseDate,
                CreatedDate = x.CreatedDate,
                User = x.User,
                Lat = x.Lat,
                Lng = x.Lng,
                Address = x.Address,
                PaymentMethod = x.PaymentMethod,
                DeliveryOtp = x.DeliveryOtp,
                DeliveredAt = x.DeliveredAt,
                DeleteReason = x.DeleteReason,
                DeletedBy = x.DeletedBy,
                DeletionDate = x.DeletionDate,
                OrderDetails = x.OrderDetails.Select(d => d.ToDto()).ToArray()
            }).ToList();

            var merchantIds = dtoList.SelectMany(x => x.OrderDetails).Select(x => x.MerchantId).Distinct().ToArray();
            var merchantKinds = await _merchantService.Queryable()
                .Where(x => merchantIds.Contains(x.Id))
                .Select(x => new { x.Id, x.MerchantKind })
                .ToDictionaryAsync(x => x.Id, x => x.MerchantKind);

            foreach (var order in dtoList)
            {
                var activeDetails = order.OrderDetails.Where(x => x.OrderDetailStatus != OrderDetailStatus.MerchantRejected &&
                                                                   x.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                                                                   x.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled).ToArray();
                order.IsJtakMarketOrder = activeDetails.Length > 0 && activeDetails.All(x => merchantKinds.TryGetValue(x.MerchantId, out var kind) && kind == MerchantKind.DarkStore);
                order.RequiresMerchantDecision = activeDetails.Any(x => x.OrderDetailStatus == OrderDetailStatus.Pending &&
                    (!merchantKinds.TryGetValue(x.MerchantId, out var kind) || kind != MerchantKind.DarkStore));
                order.CanAdminApprove = activeDetails.Any(x => x.OrderDetailStatus == OrderDetailStatus.Pending) && !order.RequiresMerchantDecision;
                order.CanAdminMarkReady = order.IsJtakMarketOrder && activeDetails.Any(x => x.OrderDetailStatus == OrderDetailStatus.MerchantAccepted);
                order.AdminFlowMessage = order.RequiresMerchantDecision
                    ? "بانتظار قرار التاجر — لا تعيّن مندوباً الآن"
                    : activeDetails.Any(x => x.OrderDetailStatus == OrderDetailStatus.MerchantAccepted)
                        ? "وافق التاجر ويقوم بالتجهيز — انتظر علامة جاهز للاستلام"
                        : activeDetails.Length > 0 && activeDetails.All(x => x.OrderDetailStatus == OrderDetailStatus.ReadyForPickup)
                            ? "الطلب جاهز — عيّن مندوب توصيل"
                            : order.IsJtakMarketOrder ? "طلب جيتك ماركت" : null;
            }

            return new TableResponseModel<OrderDto>
            {
                Items = dtoList.ToArray(),
                TotalRecords = totalRecords
            };
        }

        /// <summary>
        /// Safely archive/soft-delete an order with mandatory reason
        /// </summary>
        [HttpPost]
        [Route("Archive/{id}")]
        public async Task<ActionResult<bool>> Archive(int id, [FromBody] ArchiveOrderRequest request)
        {
            if (string.IsNullOrWhiteSpace(request?.Reason))
                return BadRequest(ApiErr.Create("سبب الأرشفة إلزامي."));

            var order = await _ouow.Context.Orders.FirstOrDefaultAsync(o => o.Id == id);
            if (order == null) return NotFound();

            var beforeState = new
            {
                order.Id,
                order.OrderStatus,
                order.DeletionDate,
                order.DeletedBy,
                order.DeleteReason
            };

            order.DeletionDate = DateTime.UtcNow;
            order.DeletedBy = User.GetUserId().ToString();
            order.DeleteReason = request.Reason.Trim();

            await _ouow.SaveChangesAsync();

            var afterState = new
            {
                order.Id,
                order.OrderStatus,
                order.DeletionDate,
                order.DeletedBy,
                order.DeleteReason
            };

            if (_auditService != null)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Orders",
                    Action = "Archive",
                    EntityType = "Order",
                    EntityId = id.ToString(),
                    Description = $"أرشفة الطلب #{id} بسبب: {request.Reason.Trim()}",
                    Result = "Success",
                    BeforeState = beforeState,
                    AfterState = afterState
                });
            }

            return true;
        }

        /// <summary>
        /// Restore an archived order to active list
        /// </summary>
        [HttpPost]
        [Route("Restore/{id}")]
        public async Task<ActionResult<bool>> Restore(int id)
        {
            var order = await _ouow.Context.Orders.FirstOrDefaultAsync(o => o.Id == id);
            if (order == null) return NotFound();

            if (order.DeletionDate == null)
                return true; // Idempotent

            var beforeState = new
            {
                order.Id,
                order.OrderStatus,
                order.DeletionDate,
                order.DeletedBy,
                order.DeleteReason
            };

            order.DeletionDate = null;
            order.DeletedBy = null;
            order.DeleteReason = null;

            await _ouow.SaveChangesAsync();

            var afterState = new
            {
                order.Id,
                order.OrderStatus,
                order.DeletionDate,
                order.DeletedBy,
                order.DeleteReason
            };

            if (_auditService != null)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Orders",
                    Action = "Restore",
                    EntityType = "Order",
                    EntityId = id.ToString(),
                    Description = $"استعادة الطلب #{id} من الأرشيف",
                    Result = "Success",
                    BeforeState = beforeState,
                    AfterState = afterState
                });
            }

            return true;
        }

        ///// <summary>                                           
        ///// Change order status   +---------+                   
        /////                       |  Order  |                   
        /////                       +----+----+                   
        /////                            |                        
        /////                         Success                     
        /////                            |                        
        ///// ---------------------------|------------------------
        /////   +-------------------+    |                        
        /////   |                   |    |                        
        /////   |                +--+----+-------+                
        /////   |          +-----+ Order Details +----+           
        ///// Found?       |     +---------------+    |           
        /////   |       Merchant                   Merchant       
        /////   |       Rejected?                  Accepted?      
        /////   |          |                          |           
        /////   | +--------+--------+        +--------+--------+  
        /////   +-+ Find Alternative|        | Notify Delivery |  
        /////     +--------+--------+        +--------+--------+  
        /////              |                          |           
        /////              |                 +--------+--------+  
        /////          Not Found?            |Shipping Started |  
        /////              |                 +--------+--------+  
        /////              |                          |           
        /////     +--------+--------+        +--------+--------+  
        /////     | Notify Customer |        |    Delivered    |  
        /////     +-----------------+        +--------+--------+  
        ///// </summary>
        ///// <returns></returns>
        ///// <summary>
        ///// Get a specific order with Details
        ///// </summary>
        ///// <returns></returns>

        [HttpPost]
        [Route("AcceptChange/{id}")]
        public async Task<ActionResult<bool>> AcceptChange(int id)
        {
            var order = await _service.CustomerAcceptOrderChange(id, User.GetUserId());

            // Notify new merchants
            var merchantOrders = order.OrderDetails.GroupBy(x => x.MerchantId).ToArray();
            foreach (var merchantOrder in merchantOrders)
            {
                var ownerId = await _merchantService.GetOwnerId(merchantOrder.Key);
                var details = merchantOrder.ToArray();
                await _notificationService.SendMerchantNewOrderRecived(new[] { ownerId }, order.Id, details);
            }
            return true;
        }


        [HttpPost]
        [Route("Cancel/{id}")]
        public async Task<ActionResult<bool>> DeliveryCancel(int id, [FromBody] AdminOrderActionRequestDto dto = null)
        {
            if (string.IsNullOrWhiteSpace(dto?.Reason))
            {
                if (_auditService != null)
                {
                    await _auditService.LogAsync(new AdminAuditLogEntry
                    {
                        Module = "Orders",
                        Action = "Cancel",
                        EntityType = "Order",
                        EntityId = id.ToString(),
                        Description = $"محاولة إلغاء الطلب #{id} بدون سبب",
                        Result = "Failed",
                        FailureReason = "يجب تحديد سبب رفض الطلب."
                    });
                }
                return BadRequest(ApiErr.Create("يجب تحديد سبب رفض الطلب."));
            }
            var order = await _service.FindAsync(id);
            if (order == null) return NotFound();
            if (order.OrderDetails != null && order.OrderDetails.All(x =>
                x.OrderDetailStatus == OrderDetailStatus.DeliveryCanceled ||
                x.OrderDetailStatus == OrderDetailStatus.MerchantRejected ||
                x.OrderDetailStatus == OrderDetailStatus.CustomerCanceled))
                return true;
            var hadDelivered = order.OrderDetails.Any(x => x.OrderDetailStatus == OrderDetailStatus.Delivered);
            if (hadDelivered)
            {
                if (_auditService != null)
                {
                    await _auditService.LogAsync(new AdminAuditLogEntry
                    {
                        Module = "Orders",
                        Action = "Cancel",
                        EntityType = "Order",
                        EntityId = id.ToString(),
                        Description = $"محاولة إلغاء الطلب #{id} الذي تم تسليمه مسبقاً",
                        Result = "Failed",
                        FailureReason = "لا يمكن رفض طلب تم تسليمه."
                    });
                }
                return BadRequest(ApiErr.Create("لا يمكن رفض طلب تم تسليمه. استخدم مسار المرتجعات أو التصحيح المالي."));
            }
            var orderMerchantIds = order.OrderDetails.Select(x => x.MerchantId).Distinct().ToArray();
            var isJtakMarket = await _merchantService.Queryable()
                .Where(x => orderMerchantIds.Contains(x.Id))
                .AllAsync(x => x.MerchantKind == MerchantKind.DarkStore);
            order = await _service.DeliveryCancelOrder(id);
            order.Notes = dto.Reason.Trim();

            // Delivery should return products to each merchant (offline), Without return confirmation
            // Bills are preserved for auditability (never deleted), but deactivated from dues
            var bills = await _billService.Queryable().Where(x => x.OrderId == id).ToArrayAsync();
            foreach (var bill in bills)
            {
                bill.IsAddedToDues = false;
                _billService.Update(bill);
            }

            // Reverse double-entry ledger entries if order was delivered
            await _ledgerService.PostOrderCancellationReversalAsync(id, $"Canceled by admin: {dto.Reason.Trim()}");

            // Release reserved warehouse batch inventory
            await _batchService.ReleaseReservationAsync(id, reason: dto.Reason.Trim());

            // Revert legacy delivery balance if it had been delivered
            if (hadDelivered && order.DeliveryId.HasValue)
            {
                var recivedAmount = bills.Where(x => x.PaymentMethod == 0).Sum(x => x.TotalAmount);
                if (recivedAmount > 0)
                {
                    var dUser = await _userManager.Users.Where(x => x.Id == order.DeliveryId.Value).Select(x => x.FullName).FirstOrDefaultAsync();
                    await _balanceService.DecreaseAppBalance(order.DeliveryId.Value, recivedAmount, dUser);
                }
            }

            var merchantIds = order.OrderDetails.Select(x => x.MerchantId).ToArray().Distinct();
            foreach (var merchantId in merchantIds)
            {
                var mId = await _merchantService.GetOwnerId(merchantId);
                // Notify related merchant about canceled order
                await _notificationService.SendOrderCanceled(new[] { mId }, id, order.OrderDetails.Where(x => x.MerchantId == merchantId).ToArray());
            }

            await _notificationService.SendCustomerOrderRejected(new[] { order.UserId }, id,
                isJtakMarket ? "جيتك ماركت" : "إدارة جيتك", dto.Reason.Trim());

            await _auow.SaveChangesAsync();

            if (_auditService != null)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Orders",
                    Action = "Cancel",
                    EntityType = "Order",
                    EntityId = id.ToString(),
                    Description = $"إلغاء الطلب #{id} بسبب: {dto.Reason.Trim()}",
                    Result = "Success",
                    AfterState = new { OrderId = id, Notes = dto.Reason.Trim() }
                });
            }

            return true;
        }

        [HttpPost]
        [Route("Accept/{id}")]
        [Route("Approve/{id}")]
        public async Task<ActionResult<bool>> Accept(int id, [FromBody] AdminOrderActionRequestDto dto = null)
        {
            var currentOrder = await _service.FindAsync(id);
            if (currentOrder == null)
                return NotFound();

            var actionableDetails = currentOrder.OrderDetails
                .Where(x => x.OrderDetailStatus != OrderDetailStatus.MerchantRejected &&
                            x.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                            x.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled &&
                            x.OrderDetailStatus == OrderDetailStatus.Pending)
                .ToArray();

            if (dto?.MerchantId.HasValue == true)
            {
                actionableDetails = actionableDetails.Where(x => x.MerchantId == dto.MerchantId.Value).ToArray();
            }

            var merchantIds = actionableDetails.Select(x => x.MerchantId).Distinct().ToArray();
            if (merchantIds.Length == 0)
            {
                var alreadyAccepted = currentOrder.OrderDetails.Any(x => x.OrderDetailStatus == OrderDetailStatus.MerchantAccepted);
                if (alreadyAccepted) return true;
                return BadRequest(ApiErr.Create("لا توجد عناصر بانتظار الموافقة في هذا الطلب."));
            }

            await _service.MerchantAccept(id, merchantIds);

            // Notify merchants
            foreach (var mid in merchantIds)
            {
                var ownerId = await _merchantService.GetOwnerId(mid);
                await _notificationService.SendMerchantNewOrderRecived(new[] { ownerId }, id, actionableDetails.Where(x => x.MerchantId == mid).ToArray());
            }

            var admins = (await _userManager.GetUsersInRoleAsync(AppRoleName.Admin.ToString())).Where(x => x.IsActive).Select(x => x.Id).ToArray();
            if (admins.Length > 0)
                await _notificationService.SendAdminMerchantDecision(admins, id, true, "إدارة جيتك", dto?.Reason);

            if (_trackingHub != null)
            {
                await _trackingHub.Clients.Group($"order_{id}").SendAsync("OnOrderAccepted", new { orderId = id });
            }

            if (_auditService != null)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Orders",
                    Action = "Approve",
                    EntityType = "Order",
                    EntityId = id.ToString(),
                    Description = $"الموافقة على الطلب #{id} وبدء تجهيزه من المتاجر ({string.Join(", ", merchantIds)})",
                    Result = "Success",
                    AfterState = new { OrderId = id, MerchantIds = merchantIds, Reason = dto?.Reason }
                });
            }

            return true;
        }

        [HttpPost]
        [Route("Reject/{id}")]
        public async Task<ActionResult<bool>> Reject(int id, [FromBody] AdminOrderActionRequestDto dto)
        {
            if (string.IsNullOrWhiteSpace(dto?.Reason))
            {
                if (_auditService != null)
                {
                    await _auditService.LogAsync(new AdminAuditLogEntry
                    {
                        Module = "Orders",
                        Action = "Reject",
                        EntityType = "Order",
                        EntityId = id.ToString(),
                        Description = $"محاولة رفض الطلب #{id} بدون سبب",
                        Result = "Failed",
                        FailureReason = "يجب تحديد سبب رفض الطلب."
                    });
                }
                return BadRequest(ApiErr.Create("يجب تحديد سبب رفض الطلب."));
            }

            var currentOrder = await _service.FindAsync(id);
            if (currentOrder == null)
                return NotFound();

            var actionableDetails = currentOrder.OrderDetails
                .Where(x => x.OrderDetailStatus != OrderDetailStatus.MerchantRejected &&
                            x.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                            x.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled)
                .ToArray();

            if (dto?.MerchantId.HasValue == true)
            {
                actionableDetails = actionableDetails.Where(x => x.MerchantId == dto.MerchantId.Value).ToArray();
            }

            if (actionableDetails.Length == 0)
            {
                return BadRequest(ApiErr.Create("تم اتخاذ قرار بشأن هذا الطلب مسبقاً ولا يمكن رفضه الآن."));
            }

            if (actionableDetails.Any(x => x.OrderDetailStatus == OrderDetailStatus.Delivered))
            {
                return BadRequest(ApiErr.Create("لا يمكن رفض طلب تم تسليمه بالفعل."));
            }

            // Release reservation for dark store / inventory items
            foreach (var mod in actionableDetails)
            {
                await _batchService.ReleaseReservationAsync(id, mod.Id, reason: dto.Reason);
            }

            foreach (var mod in actionableDetails)
            {
                mod.OrderDetailStatus = OrderDetailStatus.MerchantRejected;
                mod.Warning = dto.Reason.Trim();
            }
            currentOrder.Notes = dto.Reason.Trim();

            _service.Log(id, OrderDetailStatus.MerchantRejected, actionableDetails, currentOrder.DeliveryId);
            await _ouow.SaveChangesAsync();

            // Notify customer with exact reason
            await _notificationService.SendCustomerOrderRejected(new[] { currentOrder.UserId }, id, "إدارة جيتك", dto.Reason.Trim());

            var merchantIds = actionableDetails.Select(x => x.MerchantId).Distinct().ToArray();
            foreach (var mid in merchantIds)
            {
                var ownerId = await _merchantService.GetOwnerId(mid);
                await _notificationService.SendOrderCanceled(new[] { ownerId }, id, actionableDetails.Where(x => x.MerchantId == mid).ToArray());
            }

            if (_trackingHub != null)
            {
                await _trackingHub.Clients.Group($"order_{id}").SendAsync("OnOrderRejected", new { orderId = id, reason = dto.Reason.Trim() });
            }

            if (_auditService != null)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Orders",
                    Action = "Reject",
                    EntityType = "Order",
                    EntityId = id.ToString(),
                    Description = $"رفض الطلب #{id} بسبب: {dto.Reason.Trim()}",
                    Result = "Success",
                    AfterState = new { OrderId = id, Reason = dto.Reason.Trim(), RejectedDetailsCount = actionableDetails.Length }
                });
            }

            return true;
        }

        [HttpPost]
        [Route("Preparing/{id}")]
        public async Task<ActionResult<bool>> Preparing(int id)
        {
            var currentOrder = await _service.FindAsync(id);
            if (currentOrder == null) return NotFound();

            var pendingDetails = currentOrder.OrderDetails
                .Where(x => x.OrderDetailStatus == OrderDetailStatus.Pending)
                .ToArray();

            if (pendingDetails.Length > 0)
            {
                var merchantIds = pendingDetails.Select(x => x.MerchantId).Distinct().ToArray();
                await _service.MerchantAccept(id, merchantIds);
            }

            if (_auditService != null)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Orders",
                    Action = "Preparing",
                    EntityType = "Order",
                    EntityId = id.ToString(),
                    Description = $"بدء تجهيز الطلب #{id}",
                    Result = "Success"
                });
            }

            return true;
        }

        [HttpPost]
        [Route("Ready/{id}")]
        public async Task<ActionResult<bool>> Ready(int id, [FromQuery] int? merchantId = null)
        {
            var currentOrder = await _service.FindAsync(id);
            if (currentOrder == null)
                return NotFound();

            var actionableDetails = currentOrder.OrderDetails
                .Where(x => x.OrderDetailStatus == OrderDetailStatus.MerchantAccepted)
                .ToArray();

            if (merchantId.HasValue)
            {
                actionableDetails = actionableDetails.Where(x => x.MerchantId == merchantId.Value).ToArray();
            }

            var merchantIds = actionableDetails.Select(x => x.MerchantId).Distinct().ToArray();
            if (merchantIds.Length == 0)
            {
                var alreadyReady = currentOrder.OrderDetails.Any(x => x.OrderDetailStatus == OrderDetailStatus.ReadyForPickup);
                if (alreadyReady) return true;

                if (_auditService != null)
                {
                    await _auditService.LogAsync(new AdminAuditLogEntry
                    {
                        Module = "Orders",
                        Action = "Ready",
                        EntityType = "Order",
                        EntityId = id.ToString(),
                        Description = $"فشل نقل الطلب #{id} إلى جاهز للاستلام",
                        Result = "Failed",
                        FailureReason = "لا توجد عناصر مقبولة بانتظار تجهيزها في هذا الطلب."
                    });
                }
                return BadRequest(ApiErr.Create("لا توجد عناصر مقبولة بانتظار تجهيزها في هذا الطلب."));
            }

            var order = await _service.MerchantMarkReady(id, merchantIds);

            // Deduct reserved stock upon readiness only for dark store merchants being marked ready
            foreach (var mid in merchantIds)
            {
                await _batchService.DeductReservedStockAsync(id, merchantId: mid);
            }

            var firstMerchant = await _merchantService.FindAsync(merchantIds[0]);
            var merchantTitle = firstMerchant?.MerchantKind == MerchantKind.DarkStore ? "جيتك ماركت" : (firstMerchant?.Title ?? "جيتك");

            if (order.DeliveryId.HasValue)
                await _notificationService.SendDeliveryOrderReadyForPickup(new[] { order.DeliveryId.Value }, id, merchantTitle);

            if (order.UserId != Guid.Empty)
                await _notificationService.SendCustomerOrderReadyForPickup(new[] { order.UserId }, id, merchantTitle);

            if (_trackingHub != null)
            {
                await _trackingHub.Clients.Group($"order_{id}").SendAsync("OnOrderReadyForPickup", new { orderId = id, merchantTitle });
                if (order.DeliveryId.HasValue)
                {
                    await _trackingHub.Clients.User(order.DeliveryId.Value.ToString()).SendAsync("OnOrderReadyForPickup", new { orderId = id, merchantTitle });
                }
            }

            if (_auditService != null)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Orders",
                    Action = "Ready",
                    EntityType = "Order",
                    EntityId = id.ToString(),
                    Description = $"تأكيد جاهزية الطلب #{id} للاستلام من قبل المندوب",
                    Result = "Success",
                    AfterState = new { OrderId = id, MerchantIds = merchantIds }
                });
            }

            return true;
        }

        [HttpPost]
        [Route("ConfirmPickup/{id}")]
        public async Task<ActionResult<bool>> ConfirmPickup(int id, [FromQuery] int? merchantId = null)
        {
            var order = await _service.FindAsync(id);
            if (order == null) return NotFound();

            if (!order.DeliveryId.HasValue)
            {
                if (_auditService != null)
                {
                    await _auditService.LogAsync(new AdminAuditLogEntry
                    {
                        Module = "Orders",
                        Action = "ConfirmPickup",
                        EntityType = "Order",
                        EntityId = id.ToString(),
                        Description = $"فشل تأكيد استلام الطلب #{id} لعدم وجود سائق",
                        Result = "Failed",
                        FailureReason = "يجب تعيين مندوب توصيل للطلب أولاً."
                    });
                }
                return BadRequest(ApiErr.Create("يجب تعيين مندوب توصيل للطلب أولاً قبل تأكيد الاستلام وبدء الشحن."));
            }

            var readyDetails = order.OrderDetails
                .Where(x => x.OrderDetailStatus == OrderDetailStatus.ReadyForPickup)
                .ToArray();

            if (merchantId.HasValue)
            {
                readyDetails = readyDetails.Where(x => x.MerchantId == merchantId.Value).ToArray();
            }

            var targetMerchantIds = readyDetails.Select(x => x.MerchantId).Distinct().ToArray();
            if (targetMerchantIds.Length == 0)
            {
                var alreadyShipping = order.OrderDetails.Any(x => x.OrderDetailStatus == OrderDetailStatus.ShippingStarted);
                if (alreadyShipping) return true;
                return BadRequest(ApiErr.Create("لا توجد عناصر جاهزة للاستلام حالياً في هذا الطلب."));
            }

            foreach (var mid in targetMerchantIds)
            {
                await _service.StartShippingOrder(id, mid, order.DeliveryId.Value);

                var midDetails = order.OrderDetails.Where(x => x.MerchantId == mid).ToArray();
                var existingBill = await _billService.Queryable().FirstOrDefaultAsync(x => x.OrderId == id && x.MerchantId == mid);
                if (existingBill == null)
                {
                    var bill = new Bill
                    {
                        MerchantId = mid,
                        OrderId = id,
                        TotalAmount = midDetails.Sum(d => d.SingleFinalPrice * d.Quantity),
                        MerchantAmount = midDetails.Sum(d => d.SingleMerchantProfit * d.Quantity),
                        JTakAmount = midDetails.Sum(d => (d.SingleFinalPrice - d.SingleMerchantProfit) * d.Quantity),
                        JTakAdditionalAmount = midDetails.Sum(d => d.SingleAdditionalProfit * d.Quantity),
                        PaymentMethod = (int)order.PaymentMethod,
                        DueDate = DateTime.UtcNow,
                        IsAddedToDues = false
                    };
                    _billService.Insert(bill);
                    await _auow.SaveChangesAsync();
                }

                await _deliveryService.RemoveOrder(order.DeliveryId.Value, id, mid);

                if (_trackingHub != null)
                {
                    await _trackingHub.Clients.Group($"order_{id}").SendAsync("OnStopCompleted", new { orderId = id, merchantId = mid, completedAt = DateTime.UtcNow });
                }
            }

            await _notificationService.SendShippingStarted(new[] { order.UserId }, id, order.OrderDetails.ToArray());

            if (_trackingHub != null)
            {
                await _trackingHub.Clients.Group($"order_{id}").SendAsync("OnShippingStarted", new { orderId = id });
            }

            if (_auditService != null)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Orders",
                    Action = "ConfirmPickup",
                    EntityType = "Order",
                    EntityId = id.ToString(),
                    Description = $"تأكيد استلام المندوب ({order.DeliveryUser}) للطلب #{id} وبدء التوصيل",
                    Result = "Success",
                    AfterState = new { OrderId = id, DriverId = order.DeliveryId, DriverName = order.DeliveryUser, MerchantIds = targetMerchantIds }
                });
            }

            return true;
        }

        [HttpPost]
        [Route("Deliver/{id}")]
        public async Task<ActionResult<bool>> Deliver(int id, [FromBody] AdminDeliverOrderRequestDto dto = null)
        {
            var currentOrder = await _service.FindAsync(id);
            if (currentOrder == null) return NotFound();

            var activeDetails = currentOrder.OrderDetails
                .Where(x => x.OrderDetailStatus != OrderDetailStatus.MerchantRejected &&
                            x.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                            x.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled)
                .ToArray();

            var isAlreadyDelivered = activeDetails.Length > 0 && activeDetails.All(x => x.OrderDetailStatus == OrderDetailStatus.Delivered);
            if (isAlreadyDelivered)
            {
                return true;
            }

            var hasInTransit = activeDetails.Any(x => x.OrderDetailStatus == OrderDetailStatus.ShippingStarted);
            var allReadyOrShipping = activeDetails.All(x => x.OrderDetailStatus == OrderDetailStatus.ReadyForPickup || x.OrderDetailStatus == OrderDetailStatus.ShippingStarted);
            if (!hasInTransit && !allReadyOrShipping)
            {
                if (_auditService != null)
                {
                    await _auditService.LogAsync(new AdminAuditLogEntry
                    {
                        Module = "Orders",
                        Action = "Deliver",
                        EntityType = "Order",
                        EntityId = id.ToString(),
                        Description = $"محاولة تسليم إداري غير صالحة للطلب #{id}",
                        Result = "Failed",
                        FailureReason = "لا يمكن تسليم الطلب مباشرة وهو في حالة الانتظار أو التجهيز."
                    });
                }
                return BadRequest(ApiErr.Create("لا يمكن تسليم الطلب مباشرة وهو في حالة الانتظار أو التجهيز. يجب تجهيز الطلب وبدء نقله أولاً."));
            }

            if (currentOrder.DeliveryId.HasValue)
            {
                var readyMids = activeDetails.Where(x => x.OrderDetailStatus == OrderDetailStatus.ReadyForPickup).Select(x => x.MerchantId).Distinct().ToArray();
                foreach (var mid in readyMids)
                {
                    await _service.StartShippingOrder(id, mid, currentOrder.DeliveryId.Value);
                }
            }

            if (!string.IsNullOrWhiteSpace(dto?.Otp))
            {
                var cleanEnteredOtp = dto.Otp.Trim().Replace(" ", "");
                cleanEnteredOtp = cleanEnteredOtp
                    .Replace('\u0660', '0').Replace('\u0661', '1').Replace('\u0662', '2').Replace('\u0663', '3').Replace('\u0664', '4')
                    .Replace('\u0665', '5').Replace('\u0666', '6').Replace('\u0667', '7').Replace('\u0668', '8').Replace('\u0669', '9')
                    .Replace('\u06F0', '0').Replace('\u06F1', '1').Replace('\u06F2', '2').Replace('\u06F3', '3').Replace('\u06F4', '4')
                    .Replace('\u06F5', '5').Replace('\u06F6', '6').Replace('\u06F7', '7').Replace('\u06F8', '8').Replace('\u06F9', '9');

                var cleanOrderOtp = (currentOrder.DeliveryOtp ?? "").Trim().Replace(" ", "");
                if (!string.Equals(cleanEnteredOtp, cleanOrderOtp, StringComparison.Ordinal))
                {
                    if (_auditService != null)
                    {
                        await _auditService.LogAsync(new AdminAuditLogEntry
                        {
                            Module = "Orders",
                            Action = "Deliver",
                            EntityType = "Order",
                            EntityId = id.ToString(),
                            Description = $"فشل التحقق من رمز PIN للتسليم الإداري للطلب #{id}",
                            Result = "Failed",
                            FailureReason = "رمز PIN غير مطابق"
                        });
                    }
                    return BadRequest(ApiErr.Create("رمز تأكيد الاستلام (PIN) المدخل غير مطابق لرمز الطلب."));
                }
            }
            else
            {
                if (string.IsNullOrWhiteSpace(dto?.Notes))
                {
                    if (_auditService != null)
                    {
                        await _auditService.LogAsync(new AdminAuditLogEntry
                        {
                            Module = "Orders",
                            Action = "Deliver",
                            EntityType = "Order",
                            EntityId = id.ToString(),
                            Description = $"محاولة تسليم إداري للطلب #{id} دون PIN أو ملاحظات",
                            Result = "Failed",
                            FailureReason = "ملاحظات التسليم الإداري إلزامية عند عدم توفر PIN"
                        });
                    }
                    return BadRequest(ApiErr.Create("في حال التسليم الإداري دون رمز التحقق (PIN)، يجب تدوين ملاحظات/سبب التسليم الإداري."));
                }
            }

            var adminUser = await _userManager.GetUserAsync(User);
            var adminName = adminUser?.FullName ?? User.Identity?.Name ?? "Admin";
            var deliveryNotes = !string.IsNullOrWhiteSpace(dto?.Notes)
                ? $"Admin Delivery ({adminName}): {dto.Notes.Trim()}"
                : $"Admin Delivery ({adminName}) with valid customer PIN";

            var order = await _service.DeliverOrder(id, currentOrder.DeliveryId ?? Guid.Empty, null, null, deliveryNotes, isAdminOverride: true);

            try
            {
                using (var transaction = await _auow.Context.Database.BeginTransactionAsync())
                {
                    try
                    {
                        var bills = await _billService.Queryable().Where(x => x.OrderId == id).ToArrayAsync();
                        foreach (var b in bills)
                        {
                            b.IsAddedToDues = true;
                            _billService.Update(b);
                        }
                        await _auow.SaveChangesAsync();

                        var isCod = order.PaymentMethod == Modules.Orders.Entities.PaymentMethod.PayOnDelivery;
                        if (bills.Length > 0)
                        {
                            bool isCompanyCash = false;
                            Guid captainUserId = order.DeliveryId ?? Guid.Empty;
                            string captainName = order.DeliveryUser ?? "Unassigned";

                            if (isCod)
                            {
                                if (dto?.CashResolutionMode == "CompanyCash" || dto?.CashResolutionMode == "Office")
                                {
                                    isCompanyCash = true;
                                    captainUserId = Guid.Empty;
                                    captainName = "Company Cash Vault";
                                }
                                else if (order.DeliveryId.HasValue)
                                {
                                    isCompanyCash = false;
                                    captainUserId = order.DeliveryId.Value;
                                }
                                else if (dto?.CashCollectedByUserId.HasValue == true)
                                {
                                    isCompanyCash = false;
                                    captainUserId = dto.CashCollectedByUserId.Value;
                                    var driverUser = await _userManager.FindByIdAsync(captainUserId.ToString());
                                    captainName = driverUser?.FullName ?? "Courier";
                                }
                                else
                                {
                                    return BadRequest(ApiErr.Create("يجب تحديد جهة تحصيل المبلغ النقدي (عهدة السائق أو خزينة الشركة) لإتمام تسليم هذا الطلب إدارياً."));
                                }
                            }

                            var merchantSplits = new List<MerchantSplitItem>();
                            foreach (var b in bills)
                            {
                                var m = await _merchantService.FindAsync(b.MerchantId);
                                merchantSplits.Add(new MerchantSplitItem
                                {
                                    MerchantId = b.MerchantId,
                                    MerchantTitle = m?.Title ?? $"Merchant #{b.MerchantId}",
                                    TotalAmount = b.TotalAmount,
                                    MerchantAmount = b.MerchantAmount,
                                    PlatformCommission = b.JTakAmount,
                                    IsPlatformOwned = m?.MerchantKind == MerchantKind.DarkStore,
                                    CaptainEarningAmount = b.JTakAdditionalAmount
                                });
                            }

                            var splitReq = new OrderDeliveredSplitRequest
                            {
                                OrderId = id,
                                CaptainUserId = captainUserId,
                                CaptainName = captainName,
                                DeliveryFee = bills.Sum(x => x.JTakAdditionalAmount),
                                TotalsIncludeDeliveryFee = true,
                                Currency = "SYP",
                                IsCod = isCod,
                                IsCompanyCash = isCompanyCash,
                                MerchantSplits = merchantSplits
                            };

                            await _ledgerService.PostOrderDeliveredSplitAsync(splitReq);

                            if (isCod && !isCompanyCash && captainUserId != Guid.Empty && !isAlreadyDelivered)
                            {
                                var recivedAmount = bills.Where(x => x.PaymentMethod == 0).Sum(x => x.TotalAmount);
                                if (recivedAmount > 0)
                                {
                                    await _balanceService.IncreaseAppBalance(captainUserId, recivedAmount, captainName);
                                }
                            }
                        }

                        await transaction.CommitAsync();
                    }
                    catch (Exception)
                    {
                        await transaction.RollbackAsync();
                    }
                }
            }
            catch (Exception) { }

            if (order.DeliveryId.HasValue)
            {
                await _deliveryService.RemoveOrder(order.DeliveryId.Value, id);
            }

            try
            {
                await _notificationService.SendCustomerOrderDelivered(new[] { order.UserId }, id);
            }
            catch { }

            try
            {
                if (_trackingHub != null)
                {
                    await _trackingHub.Clients.Group($"order_{id}").SendAsync("OnOrderDelivered", new { orderId = id, deliveredAt = DateTime.UtcNow });
                }
            }
            catch { }

            if (_auditService != null)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Orders",
                    Action = "Deliver",
                    EntityType = "Order",
                    EntityId = id.ToString(),
                    Description = $"تسليم إداري للطلب #{id} ({deliveryNotes})",
                    Result = "Success",
                    AfterState = new
                    {
                        OrderId = id,
                        DeliveredAt = DateTime.UtcNow,
                        order.PaymentMethod,
                        dto?.CashResolutionMode,
                        dto?.Notes
                    }
                });
            }

            return true;
        }

        [HttpGet]
        [Route("History/{id}")]
        public async Task<ActionResult<List<OrderStatusHistoryDto>>> GetHistory(int id)
        {
            var logs = await _service.GetLogs(id);
            var result = new List<OrderStatusHistoryDto>();
            foreach (var l in logs)
            {
                string driverName = null;
                if (l.DriverId.HasValue)
                {
                    var driver = await _userManager.FindByIdAsync(l.DriverId.Value.ToString());
                    driverName = driver?.FullName ?? driver?.UserName;
                }

                result.Add(new OrderStatusHistoryDto
                {
                    Id = l.Id,
                    OrderId = l.OrderId,
                    Status = (int)l.OrderDetailStatus,
                    StatusName = l.OrderDetailStatus.ToString(),
                    StatusArabic = GetStatusArabic(l.OrderDetailStatus),
                    CreatedDate = l.CreatedDate,
                    CreatedBy = l.CreatedBy ?? "System",
                    DriverId = l.DriverId,
                    DriverName = driverName,
                    Details = l.OrdreDetails
                });
            }
            return Ok(result);
        }

        private static string GetStatusArabic(OrderDetailStatus status) => status switch
        {
            OrderDetailStatus.Pending => "بانتظار قرار التاجر",
            OrderDetailStatus.MerchantAccepted => "قيد التجهيز من التاجر",
            OrderDetailStatus.ReadyForPickup => "جاهز للاستلام من المندوب",
            OrderDetailStatus.ShippingStarted => "قيد التوصيل مع المندوب",
            OrderDetailStatus.Delivered => "تم التسليم بنجاح",
            OrderDetailStatus.CustomerCanceled => "ملغى من العميل",
            OrderDetailStatus.DeliveryCanceled => "ملغى من الإدارة / المندوب",
            OrderDetailStatus.MerchantRejected => "مرفوض من التاجر",
            _ => status.ToString()
        };

        [HttpPut]
        [Route("UnassignDelivery/{id}")]
        public async Task<ActionResult<bool>> UnassignDelivery(int id)
        {
            var order = await _service.FindAsync(id);
            if (order == null) return NotFound();

            var prevDriverId = order.DeliveryId;
            var prevDriverName = order.DeliveryUser;

            if (order.DeliveryId.HasValue)
            {
                await _deliveryService.RemoveOrder(order.DeliveryId.Value, id);
            }

            order.DeliveryId = null;
            order.DeliveryUser = null;
            order.DeliveryLat = null;
            order.DeliveryLng = null;
            order.DeliveryLocationUpdatedAt = null;
            await _ouow.SaveChangesAsync();

            var activeDrivers = (await _userManager.GetUsersInRoleAsync(AppRoleName.Delivery.ToString()))
                .Where(x => x.IsActive)
                .Select(x => x.Id)
                .ToArray();

            if (activeDrivers.Length > 0)
            {
                await _notificationService.SendDeliveryNewOrderRecived(activeDrivers, id, order.OrderDetails.ToArray());
            }

            if (_trackingHub != null)
            {
                await _trackingHub.Clients.Group(TrackingHub.FleetDispatchGroup).SendAsync("OnNewAvailableOrder", new { orderId = id });
            }

            if (_auditService != null)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Orders",
                    Action = "AssignDriver",
                    EntityType = "Order",
                    EntityId = id.ToString(),
                    Description = $"إلغاء تعيين المندوب ({prevDriverName}) للطلب #{id}",
                    Result = "Success",
                    BeforeState = new { DriverId = prevDriverId, DriverName = prevDriverName },
                    AfterState = new { DriverId = (Guid?)null, DriverName = (string)null }
                });
            }

            return true;
        }

        [HttpPut]
        [Route("SetDelivery/{id}/{uid}")]
        public async Task<ActionResult<bool>> SetDelivery(int id, Guid uid)
        {
            if (uid == Guid.Empty)
            {
                return await UnassignDelivery(id);
            }

            var order = await _service.FindAsync(id);
            if (order == null)
                return NotFound();

            var prevDriverId = order.DeliveryId;
            var prevDriverName = order.DeliveryUser;

            var activeDetails = order.OrderDetails.Where(x => x.OrderDetailStatus != OrderDetailStatus.MerchantRejected &&
                                                               x.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                                                               x.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled).ToArray();
            if (activeDetails.Length == 0 || activeDetails.Any(x => x.OrderDetailStatus != OrderDetailStatus.ReadyForPickup))
            {
                if (_auditService != null)
                {
                    await _auditService.LogAsync(new AdminAuditLogEntry
                    {
                        Module = "Orders",
                        Action = "AssignDriver",
                        EntityType = "Order",
                        EntityId = id.ToString(),
                        Description = $"فشل تعيين مندوب للطلب #{id} لعدم جاهزية الطلب",
                        Result = "Failed",
                        FailureReason = "لا يمكن تعيين مندوب قبل أن يؤكد كل تاجر أن الطلب جاهز للاستلام."
                    });
                }
                return BadRequest(ApiErr.Create("لا يمكن تعيين مندوب قبل أن يؤكد كل تاجر أن الطلب جاهز للاستلام."));
            }

            var bestDelivery = await _userManager.Users.FirstOrDefaultAsync(x => x.Id == uid);
            if (bestDelivery == null || !await _userManager.IsInRoleAsync(bestDelivery, AppRoleName.Delivery.ToString()))
            {
                if (_auditService != null)
                {
                    await _auditService.LogAsync(new AdminAuditLogEntry
                    {
                        Module = "Orders",
                        Action = "AssignDriver",
                        EntityType = "Order",
                        EntityId = id.ToString(),
                        Description = $"فشل تعيين مندوب للطلب #{id}",
                        Result = "Failed",
                        FailureReason = "المستخدم المحدد ليس مندوب توصيل."
                    });
                }
                return BadRequest(ApiErr.Create("The selected user is not a delivery driver."));
            }

            // Enforce Driver COD Cash Custody Limit (#27: 5,000 SYP limit)
            var floatAcc = await _auow.Context.Accounts.FirstOrDefaultAsync(a =>
                a.OwnerUserId == bestDelivery.Id &&
                a.Type == AccountType.Asset &&
                a.AccountCode.StartsWith(SystemAccountCodes.CaptainCashFloatPrefix));
            decimal currentFloat = 0m;
            if (floatAcc != null)
            {
                currentFloat = await _ledgerService.GetAccountBalanceAsync(floatAcc.Id);
            }

            decimal projectedCod = 0m;
            if (order.PaymentMethod == Modules.Orders.Entities.PaymentMethod.PayOnDelivery)
            {
                projectedCod = activeDetails.Sum(x => x.Quantity * x.SingleFinalPrice);
            }

            if (currentFloat + projectedCod > 5000m)
            {
                string errMsg = projectedCod > 5000m
                    ? $"قيمة الطلب النقدية ({projectedCod:N0} ل.س) تتجاوز الحد الأقصى للعهدة النقدية للمندوب (5,000 ل.س). لا يمكن إسناد هذا الطلب لأي سائق."
                    : $"إسناد هذا الطلب سيتجاوز الحد الأقصى للعهدة النقدية للسائق (5,000 ل.س). العهدة الحالية: {currentFloat:N0} ل.س، قيمة الطلب: {projectedCod:N0} ل.س.";

                if (_auditService != null)
                {
                    await _auditService.LogAsync(new AdminAuditLogEntry
                    {
                        Module = "Orders",
                        Action = "AssignDriver",
                        EntityType = "Order",
                        EntityId = id.ToString(),
                        Description = $"فشل تعيين السائق {bestDelivery.FullName} للطلب #{id} لتجاوز حد العهدة",
                        Result = "Failed",
                        FailureReason = errMsg
                    });
                }
                return BadRequest(ApiErr.Create(errMsg));
            }

            if (order.DeliveryId.HasValue)
            {
                await _deliveryService.RemoveOrder(order.DeliveryId.Value, id);
            }

            order.DeliveryId = bestDelivery.Id;
            order.DeliveryLat = null;
            order.DeliveryLng = null;
            order.DeliveryLocationUpdatedAt = null;
            order.DeliveryUser = await _userManager.Users.Where(x => x.Id == order.DeliveryId).Select(x => x.FullName).FirstOrDefaultAsync();
            await _ouow.SaveChangesAsync();

            var customerSO = new ShippingOrderDto
            {
                OrderId = order.Id,
                DriverId = order.DeliveryId.Value,
                MerchantId = null,
                CustomerId = order.UserId,
                Lat = order.Lat,
                Lng = order.Lng,
                StopType = ShippingStopType.Dropoff,
                StopTitle = $"Customer: {order.User ?? order.Phonenumber}"
            };

            var orderMerchantIds = await _service.GetMerchantIds(id);
            var allMerchantStops = await _merchantService.GetMerchantStops(orderMerchantIds);
            var merchantsSOs = new List<ShippingOrderDto>();
            foreach (var x in allMerchantStops)
            {
                var m = await _merchantService.FindAsync(x.MerchantId);
                var isDarkStore = m != null && (m.MerchantKind == MerchantKind.DarkStore || m.Title.Contains("Dark") || m.Title.Contains("مستودع") || m.Title.Contains("Warehouse"));
                merchantsSOs.Add(new ShippingOrderDto
                {
                    OrderId = order.Id,
                    DriverId = order.DeliveryId.Value,
                    MerchantId = x.MerchantId,
                    CustomerId = order.UserId,
                    Lat = x.Lat,
                    Lng = x.Lng,
                    StopType = ShippingStopType.Pickup,
                    StopTitle = m?.Title ?? $"Merchant #{x.MerchantId}",
                    IsDarkStore = isDarkStore
                });
            }

            await _deliveryService.AddOrder(bestDelivery.Id, id, merchantsSOs.ToArray(), customerSO);

            // Sending Notification will save to DB
            await _notificationService.SendDeliveryNewOrderRecived(new[] { bestDelivery.Id }, id, order.OrderDetails.ToArray());

            if (_auditService != null)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Orders",
                    Action = "AssignDriver",
                    EntityType = "Order",
                    EntityId = id.ToString(),
                    Description = $"تعيين مندوب التوصيل {order.DeliveryUser} للطلب #{id}",
                    Result = "Success",
                    BeforeState = new { DriverId = prevDriverId, DriverName = prevDriverName },
                    AfterState = new { DriverId = bestDelivery.Id, DriverName = order.DeliveryUser }
                });
            }

            return true;
        }

        [HttpGet("{id}/LiveTrack")]
        public async Task<ActionResult<OrderLiveTrackDto>> GetLiveTrack(int id)
        {
            var order = await _service.Queryable()
                .Where(x => x.Id == id)
                .Select(x => new
                {
                    x.Id,
                    x.OrderStatus,
                    x.DeliveryId,
                    x.DeliveryUser,
                    x.DeliveryLat,
                    x.DeliveryLng,
                    x.DeliveryLocationUpdatedAt,
                    x.Lat,
                    x.Lng,
                    x.Address,
                    x.DeliveryOtp
                })
                .FirstOrDefaultAsync();

            if (order == null) return NotFound();

            var stops = await _deliveryService.GetOrderStops(id);

            // Fetch live cached driver telemetry if available
            decimal? driverLat = order.DeliveryLat;
            decimal? driverLng = order.DeliveryLng;
            double? heading = null;
            double? speed = null;
            DateTime? updatedAt = order.DeliveryLocationUpdatedAt;

            if (order.DeliveryId.HasValue)
            {
                var driverStatus = await _deliveryService.GetDeliveryStatus(order.DeliveryId.Value);
                if (driverStatus != null && driverStatus.LastLocationUpdatedAt.HasValue)
                {
                    if (!updatedAt.HasValue || driverStatus.LastLocationUpdatedAt.Value >= updatedAt.Value)
                    {
                        driverLat = driverStatus.Loc.Lat;
                        driverLng = driverStatus.Loc.Lng;
                        heading = driverStatus.Heading;
                        speed = driverStatus.Speed;
                        updatedAt = driverStatus.LastLocationUpdatedAt;
                    }
                }
            }

            var isLive = updatedAt.HasValue && (DateTime.UtcNow - updatedAt.Value).TotalMinutes < 5;

            int remainingDistanceMeters = 0;
            var currentPos = driverLat.HasValue && driverLng.HasValue ? (driverLat.Value, driverLng.Value) : (order.Lat, order.Lng);
            var pendingStops = stops.Where(s => !s.CompletedDate.HasValue).OrderBy(s => s.Index).ToList();

            var runner = currentPos;
            foreach (var stop in pendingStops)
            {
                remainingDistanceMeters += (int)runner.DistanceInMeters((stop.Lat, stop.Lng));
                runner = (stop.Lat, stop.Lng);
            }
            // Add the final delivery transit leg to the customer destination
            remainingDistanceMeters += (int)runner.DistanceInMeters((order.Lat, order.Lng));

            int etaMinutes = 0;
            if (remainingDistanceMeters > 0)
            {
                etaMinutes = (int)System.Math.Ceiling(remainingDistanceMeters / 400.0) + (pendingStops.Count * 2);
            }

            var currentStop = pendingStops.FirstOrDefault();

            var driverPhone = string.Empty;
            if (order.DeliveryId.HasValue)
            {
                driverPhone = await _userManager.Users
                    .Where(u => u.Id == order.DeliveryId.Value)
                    .Select(u => u.PhoneNumber)
                    .FirstOrDefaultAsync() ?? string.Empty;
            }

            return Ok(new OrderLiveTrackDto
            {
                OrderId = order.Id,
                OrderStatus = (int)order.OrderStatus,
                DriverId = order.DeliveryId,
                DriverName = order.DeliveryUser,
                DriverPhoneNumber = driverPhone,
                DriverLat = driverLat,
                DriverLng = driverLng,
                Heading = heading,
                Speed = speed,
                LocationUpdatedAt = updatedAt,
                IsLive = isLive,
                EtaMinutes = etaMinutes,
                RemainingDistanceMeters = remainingDistanceMeters,
                DestinationLat = order.Lat,
                DestinationLng = order.Lng,
                DestinationAddress = order.Address,
                DeliveryOtp = order.DeliveryOtp,
                CurrentStopIndex = currentStop?.Index ?? 0,
                CurrentStopTitle = currentStop?.StopTitle,
                CurrentStopIsDarkStore = currentStop?.IsDarkStore ?? false,
                Stops = stops.Select(s => new ShippingStopProgressDto
                {
                    Index = s.Index,
                    Title = s.StopTitle,
                    IsDarkStore = s.IsDarkStore,
                    IsCompleted = s.CompletedDate.HasValue,
                    Lat = s.Lat,
                    Lng = s.Lng,
                    StopType = (int)s.StopType
                }).ToList()
            });
        }
    }

    public class AdminOrderActionRequestDto
    {
        public string Reason { get; set; }
        public int? MerchantId { get; set; }
    }

    public class AdminDeliverOrderRequestDto
    {
        public string Otp { get; set; }
        public string CashResolutionMode { get; set; } // "DriverCashFloat" | "CompanyCash" | "Waived"
        public Guid? CashCollectedByUserId { get; set; }
        public string Notes { get; set; }
    }

    public class OrderStatusHistoryDto
    {
        public Guid Id { get; set; }
        public int OrderId { get; set; }
        public int Status { get; set; }
        public string StatusName { get; set; }
        public string StatusArabic { get; set; }
        public DateTime CreatedDate { get; set; }
        public string CreatedBy { get; set; }
        public Guid? DriverId { get; set; }
        public string DriverName { get; set; }
        public string Details { get; set; }
    }
}
