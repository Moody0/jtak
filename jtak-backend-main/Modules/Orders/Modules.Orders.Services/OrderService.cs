using App.Orders.Data;
using App.Shared.Data.MultiContext;
using App.Shared.Entities;
using App.Shared.Entities.Enums;
using AutoMapper;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Modules.Orders.Entities;
using Solf.Base;
using System;
using System.ComponentModel;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;

namespace Modules.Orders.Services
{
    public interface IOrderService : ISolService<Order, OrderDto>
    {
        Task<Order> FindAsync(int id);
        Task<Order> FindNoTrackingAsync(int id);
        Task<Order> GetCurrentUserCart(Guid uid);
        Task UpdateCartPrices(Guid uid);
        Task UpdateCartPricesForProduct(int id);
        Task<int> GetCurrentUserCartItemsCount(Guid uid);
        Task<int[]> GetMerchantIds(int id);
        Task<OrderDetailDto[]> GetSuccess(Guid uid);
        Task<OrderDetail[]> GetDetails(int id, Guid? uid = null);
        Task<OrderDetail> GetDetail(int id);
        Task<OrderDto[]> GetOrders(int ProductId);
        /// <summary>
        /// 
        /// </summary>
        /// <param name="ProductId"></param>
        /// <returns></returns>
        Task<Order> MerchantAccept(int orderId, params int[] merchantIds);
        Task<Order> CustomerAcceptOrderChange(int orderId, Guid? uid = null);
        Task<Order> CustomerCancelOrder(int orderId, Guid? uid = null);
        Task<Order> DeliveryCancelOrder(int orderId, Guid? uid = null);
        Task<Order> StartShippingOrder(int orderId, int merchantId, Guid derliveryId);
        Task<bool> CanDeliverOrder(int orderId, Guid derliveryId);
        Task<bool> CanStartShippingOrder(int orderId, int merchantId, Guid derliveryId);
        Task<Order> DeliverOrder(int orderId, Guid derliveryId);
        Task<Order> UpdateDeliveryLocation(int orderId, Guid deliveryId, decimal lat, decimal lng);
        void Log(int OrderId,
                     OrderDetailStatus orderDetailsStatus,
                     OrderDetail[] orderDetails = null,
                     Guid? DriverId = null);
        Task<OrderStatusChangeLog[]> GetLogs(int OrderId);
    }
    public class OrderService : SolService<Order, OrderDto>, IOrderService
    {
        private ITrackableRepository<OrderDetail, OrdersDbContext> _orderDetailRepo { get; set; }
        private ITrackableRepository<OrderStatusChangeLog, OrdersDbContext> _orderStatusChangeLogRepo { get; set; }
        private UserManager<AppUser> _userManager { get; set; }
        private IMapper _mapper { get; set; }
        private IOrdersUnitOfWork _uow { get; set; }
        public OrderService(IOrdersUnitOfWork unitOfWork,
                            IMapper mapper,
                           UserManager<AppUser> userManager,
                            ITrackableRepository<Order, OrdersDbContext> repository,
                            ITrackableRepository<OrderStatusChangeLog, OrdersDbContext> orderStatusChangeLogRepo,
                            ITrackableRepository<OrderDetail, OrdersDbContext> orderDetailRepo) : base(repository)
        {
            _orderStatusChangeLogRepo = orderStatusChangeLogRepo;
            _orderDetailRepo = orderDetailRepo;
            _userManager = userManager;
            _mapper = mapper;
            _uow = unitOfWork;
        }


        public async Task<Order> FindAsync(int id) =>
            await Queryable().Include(x => x.OrderDetails)
                             .FirstOrDefaultAsync(x => x.Id == id);


        public async Task<Order> FindNoTrackingAsync(int id) =>
            await Queryable().AsNoTracking()
                             .Include(x => x.OrderDetails)
                             .FirstOrDefaultAsync(x => x.Id == id);

        public async Task<Order> GetCurrentUserCart(Guid uid)
        {
            var cart = await Repository.Queryable()
                                       .AsNoTracking()
                                       .Include(x => x.OrderDetails)
                                       .FirstOrDefaultAsync(x => x.UserId == uid && x.OrderStatus == OrderStatus.Pending);
            if (cart == null)
            {
                cart = new Order { UserId = uid, OrderStatus = OrderStatus.Pending };
                Repository.Insert(cart);
                await _uow.SaveChangesAsync();
                cart = await Repository.Queryable()
                                       .Include(x => x.OrderDetails)
                                       .FirstOrDefaultAsync(x => x.UserId == uid && x.OrderStatus == OrderStatus.Pending);
            }

            // Check for warning (count, price and delivery location changes)
            var anyChanges = false;
            foreach (var OrderDetail in cart.OrderDetails)
            {
                //var price = OrderDetail.Product.Price;

                //TODO: fetch price from Catalog module
                var price = 0;
                if (OrderDetail.SinglePrice != price)
                {
                    // Price changed
                    anyChanges = true;
                    OrderDetail.Warning = $"لقد تغير سعر هذا المنتج من {OrderDetail.SingleFinalPrice} إلى {price}";
                    OrderDetail.SinglePrice = price;
                }
            }
            if (anyChanges)
            {
                await _uow.SaveChangesAsync();
            }
            return cart;
        }

        public async Task<int> GetCurrentUserCartItemsCount(Guid uid)
        {
            var cart = await GetCurrentUserCart(uid);
            return cart?.OrderDetails?.Count() ?? 0;
        }

        public async Task UpdateCartPrices(Guid uid)
        {
            var cart = await GetCurrentUserCart(uid);
            updateCart(cart);
            await _uow.SaveChangesAsync();
        }
        public async Task UpdateCartPricesForProduct(int id)
        {
            var carts = await Repository.Queryable()
                                        .Include(x => x.OrderDetails)
                                        .Where(x => x.OrderDetails.Any(o => o.ProductId == id) && x.OrderStatus == OrderStatus.Pending)
                                        .ToArrayAsync();

            foreach (var cart in carts) updateCart(cart);
            await _uow.SaveChangesAsync();
        }


        private void updateCart(Order cart)
        {
            decimal price = 0;

            foreach (var orderDetail in cart.OrderDetails)
            {
                price += orderDetail.SingleFinalPrice * orderDetail.Quantity;
            }

            //cart.Price = price;
        }

        public async Task<OrderDetail[]> GetDetails(int id, Guid? uid = null) =>
            await _orderDetailRepo.Queryable()
                                  .AsNoTracking()
                                  .Where(x => x.OrderId == id && (!uid.HasValue || x.Order.UserId == uid))
                                  .ToArrayAsync();

        public async Task<OrderDetail> GetDetail(int id) =>
            await _orderDetailRepo.Queryable()
                                  .AsNoTracking()
                                  .FirstOrDefaultAsync(x => x.Id == id);


        public async Task<OrderDetailDto[]> GetSuccess(Guid uid) =>
            await _orderDetailRepo.Queryable()
                                  .AsNoTracking()
                                  .Include(x => x.Order)
                                  .Where(x => x.Order.OrderStatus == OrderStatus.Success && x.Order.UserId == uid)
                                  .Select(x => _mapper.Map<OrderDetailDto>(x))
                                  .ToArrayAsync();


        public async Task<OrderDto[]> GetOrders(int ProductId)
        {
            var orders = await Queryable().AsNoTracking()
                                          .Include(x => x.OrderDetails)
                                          .Where(x => x.OrderDetails.Any(d => d.ProductId == ProductId) && x.OrderStatus != OrderStatus.Pending)
                                          .ToArrayAsync();

            return orders?.Select(x => _mapper.Map<OrderDto>(x)).ToArray();
        }

        public override IQueryable<Order> Search(IQueryable<Order> query, string keyword)
        {
            keyword = keyword?.Trim().ToLower();
            if (keyword == null) return query;
            return query.Where(x => x.User.ToLower().Contains(keyword) ||
                                    x.Phonenumber.ToLower().Contains(keyword) ||
                                    x.Id.ToString() == keyword ||
            x.OrderDetails.Any(d => d.ProductTitle.ToLower().Contains(keyword)));
        }

        public override IQueryable<OrderDto> Search(IQueryable<OrderDto> query, string keyword)
        {
            keyword = keyword?.Trim().ToLower();
            if (keyword == null) return query;
            return query.Where(x => x.User.ToLower().Contains(keyword) ||
                                    x.Phonenumber.ToLower().Contains(keyword) ||
                                    x.Id.ToString() == keyword ||
            x.OrderDetails.Any(d => d.ProductTitle.ToLower().Contains(keyword)));
        }

        public override IQueryable<Order> OrderBy(IQueryable<Order> query, string orderColumn, ListSortDirection dir)
        {
            if (string.IsNullOrEmpty(orderColumn)) return query;
            query = orderColumn switch
            {
                //_ => isAsc ? query.OrderBy(x => x.Id) : query.OrderByDescending(x => x.Id),
                _ => base.OrderBy(query, orderColumn, dir),
            };
            return query;
        }

        public async Task<Order> CustomerAcceptOrderChange(int orderId, Guid? uid = null)
        {
            var order = await FindAsync(orderId);

            if (order == null || (uid.HasValue && order.UserId != uid.Value))
                throw new UnauthorizedAccessException("You cannot update this order.");

            var orderDetails = order.OrderDetails.Where(x => x.OrderDetailStatus == OrderDetailStatus.CustomerPending).ToArray();

            //var wasMerchantRejected = orderDetails.Any(x => x.OrderDetailStatus == OrderDetailStatus.MerchantRejected);//

            //if (!wasMerchantRejected)
            //    throw new Exception("Can't Accept this order change!");

            foreach (var orderdetail in orderDetails)
            {
                orderdetail.OrderDetailStatus = OrderDetailStatus.Pending;
            }
            Log(orderId, OrderDetailStatus.Pending, orderDetails);
            await _uow.SaveChangesAsync();

            return order;
        }

        public async Task<Order> CustomerCancelOrder(int orderId, Guid? uid = null)
        {
            var order = await FindAsync(orderId);

            if (order == null || (uid.HasValue && order.UserId != uid))
                throw new Exception("You Cannot Cancel this order!");

            var orderDetails = order.OrderDetails.ToArray();
            var allPending = orderDetails.Where(x => x.OrderDetailStatus != OrderDetailStatus.MerchantRejected)
                                         .All(x => x.OrderDetailStatus == OrderDetailStatus.CustomerPending || x.OrderDetailStatus == OrderDetailStatus.Pending);

            if (!allPending)
                throw new Exception("Can't Cancel this order!");

            foreach (var orderdetail in orderDetails)
            {
                orderdetail.OrderDetailStatus = OrderDetailStatus.CustomerCanceled;
            }
            Log(orderId, OrderDetailStatus.CustomerCanceled, orderDetails);
            await _uow.SaveChangesAsync();
            return order;
        }

        public async Task<Order> DeliveryCancelOrder(int orderId, Guid? uid = null)
        {
            var order = await FindAsync(orderId);

            if (order == null || (uid.HasValue && order.DeliveryId != uid))
                throw new Exception("You Cannot Cancel this order!");

            var orderDetails = order.OrderDetails.Where(x => x.OrderDetailStatus != OrderDetailStatus.MerchantRejected && x.OrderDetailStatus != OrderDetailStatus.CustomerCanceled).ToArray();
            //var allShipping = orderDetails.Where(x => x.OrderDetailStatus != OrderDetailStatus.MerchantRejected)
            //                              .All(x => x.OrderDetailStatus == OrderDetailStatus.ShippingStarted);
            //
            //if (!allShipping)
            //    throw new Exception("Can't Cancel this order!");

            foreach (var orderdetail in orderDetails)
            {
                orderdetail.OrderDetailStatus = OrderDetailStatus.DeliveryCanceled;
            }
            order.DeliveryLat = null;
            order.DeliveryLng = null;
            order.DeliveryLocationUpdatedAt = null;
            Log(orderId, OrderDetailStatus.DeliveryCanceled, orderDetails);
            await _uow.SaveChangesAsync();
            return order;
        }

        public async Task<Order> MerchantAccept(int orderId, params int[] merchantIds)
        {
            var order = await FindAsync(orderId);
            if (order == null)
                throw new Exception("Order not found.");

            var merchantOrderdetails = order.OrderDetails.Where(x => merchantIds.Contains(x.MerchantId)).ToArray();
            var actionable = merchantOrderdetails.Where(x => x.OrderDetailStatus != OrderDetailStatus.MerchantRejected).ToArray();
            var allPendingOrAccepted = actionable.All(x => x.OrderDetailStatus == OrderDetailStatus.Pending ||
                                                           x.OrderDetailStatus == OrderDetailStatus.MerchantAccepted);

            if (!allPendingOrAccepted || !actionable.Any(x => x.OrderDetailStatus == OrderDetailStatus.Pending))
                throw new Exception("Can't Accept this order!");

            foreach (var merchantOrderdetail in merchantOrderdetails.Where(x => x.OrderDetailStatus == OrderDetailStatus.Pending))
            {
                merchantOrderdetail.OrderDetailStatus = OrderDetailStatus.MerchantAccepted;
            }
            Log(orderId, OrderDetailStatus.MerchantAccepted, merchantOrderdetails);
            await _uow.SaveChangesAsync();
            return order;
        }


        public async Task<Order> StartShippingOrder(int orderId, int merchantId, Guid derliveryId)
        {
            var order = await FindAsync(orderId);
            var user = await _userManager.FindByIdAsync(derliveryId.ToString());
            if (order == null || user == null)
                throw new Exception("Order or delivery driver not found.");
            var isDelivery = await _userManager.IsInRoleAsync(user, AppRoleName.Delivery.ToString());
            if (!isDelivery)
                throw new Exception("You Cannot Start Shipping this order!");

            var merchantOrderdetails = order.OrderDetails.Where(x => x.MerchantId == merchantId && x.OrderDetailStatus == OrderDetailStatus.MerchantAccepted)
                                                         .ToArray();
            //var allMerchantAccepted = merchantOrderdetails.All(x => x.OrderDetailStatus == OrderDetailStatus.MerchantAccepted);
            //
            //if (!allMerchantAccepted)
            //    throw new Exception("Can't start shiping this order! not all items are merchant accepted!");

            foreach (var merchantOrderdetail in merchantOrderdetails)
            {
                merchantOrderdetail.OrderDetailStatus = OrderDetailStatus.ShippingStarted;
            }
            Log(orderId, OrderDetailStatus.ShippingStarted, merchantOrderdetails);
            await _uow.SaveChangesAsync();
            return order;
        }

        public async Task<bool> CanDeliverOrder(int orderId, Guid deliveryId) =>
            await Queryable().AnyAsync(o => o.Id == orderId &&
                                           o.DeliveryId == deliveryId &&
                                           o.OrderDetails.Any(x => x.OrderDetailStatus == OrderDetailStatus.ShippingStarted) &&
                                           o.OrderDetails.Where(x => x.OrderDetailStatus != OrderDetailStatus.MerchantRejected &&
                                                                    x.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                                                                    x.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled)
                                                         .All(x => x.OrderDetailStatus == OrderDetailStatus.ShippingStarted));

        public async Task<bool> CanStartShippingOrder(int orderId, int merchantId, Guid deliveryId) =>
            await Queryable().AnyAsync(o => o.DeliveryId == deliveryId && 
                                            o.OrderDetails.Any(x => x.OrderId == orderId && x.MerchantId == merchantId && x.OrderDetailStatus == OrderDetailStatus.MerchantAccepted));


        public async Task<Order> DeliverOrder(int orderId, Guid deliveryId)
        {
            var order = await FindAsync(orderId);
            if (order == null || order.DeliveryId != deliveryId)
                throw new UnauthorizedAccessException("You Cannot Derliver this order!");

            var activeDetails = order.OrderDetails.Where(x => x.OrderDetailStatus != OrderDetailStatus.MerchantRejected &&
                                                               x.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                                                               x.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled)
                                                  .ToArray();
            if (activeDetails.Length == 0 || activeDetails.Any(x => x.OrderDetailStatus != OrderDetailStatus.ShippingStarted))
                throw new Exception("Every active merchant pickup must be in transit before the order can be delivered.");

            foreach (var orderdetail in activeDetails)
            {
                orderdetail.OrderDetailStatus = OrderDetailStatus.Delivered;
            }
            order.DeliveryLat = null;
            order.DeliveryLng = null;
            order.DeliveryLocationUpdatedAt = null;
            Log(orderId, OrderDetailStatus.Delivered, activeDetails);
            await _uow.SaveChangesAsync();
            return order;
        }

        public async Task<Order> UpdateDeliveryLocation(int orderId, Guid deliveryId, decimal lat, decimal lng)
        {
            var order = await FindAsync(orderId);
            if (order == null || order.DeliveryId != deliveryId)
                throw new UnauthorizedAccessException("You cannot update this order location.");

            var isShipping = order.OrderDetails.Any(x => x.OrderDetailStatus == OrderDetailStatus.ShippingStarted);
            if (!isShipping)
                throw new InvalidOperationException("Location can only be shared while an order is shipping.");

            order.DeliveryLat = lat;
            order.DeliveryLng = lng;
            order.DeliveryLocationUpdatedAt = DateTime.UtcNow;
            await _uow.SaveChangesAsync();
            return order;
        }


        public void Log(int OrderId, OrderDetailStatus orderDetailsStatus, OrderDetail[] orderDetails = null, Guid? DriverId = null)
        {
            var hasDetails = (orderDetails?.Length ?? 0) > 0;
            _orderStatusChangeLogRepo.Insert(new OrderStatusChangeLog
            {
                OrderId = OrderId,
                OrderDetailStatus = orderDetailsStatus,
                OrdreDetails = hasDetails ? JsonSerializer.Serialize(orderDetails.Select(x => x.ToDto())) : null,
                DriverId = DriverId
            });
        }

        public async Task<OrderStatusChangeLog[]> GetLogs(int OrderId) =>
                await _orderStatusChangeLogRepo.Queryable()
                                               .AsNoTracking()
                                               .Where(x => x.OrderId == OrderId)
                                               .OrderByDescending(x => x.CreatedDate)
                                               .ToArrayAsync();

        public async Task<int[]> GetMerchantIds(int id) =>
            await _orderDetailRepo.Queryable()
                                  .Where(x => x.OrderId == id)
                                  .Select(d => d.MerchantId)
                                  .Distinct()
                                  .ToArrayAsync();
    }
}
