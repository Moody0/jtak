using App.Models;
using App.Shared.Data.App;
using App.Shared.Services;
using App.Shared.Services.BackroundTasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Modules.Accounting.Services;
using Modules.Catalog.Services;
using Modules.Orders.Entities;
using Modules.Orders.Services;
using Modules.Shipping.Services;
using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

namespace App.BackgroundTasks
{
    public class OrderCheckingService : SolScheduledService
    {
        private IServiceProvider _services;
        private IOrderService _orderService;
        private IDeliveryService _deliveryService;
        private IMerchantService _merchantService;
        private IBillService _billService;
        private IBalanceService _balanceService;
        private IGenericSettingService _settingsService;
        //private UserManager<AppUser> _userManager;
        private IAppUnitOfWork _uow;
        private AppPreferences appPreferences;
        private ILogger _logger;
        public OrderCheckingService(IServiceProvider services,
            //UserManager<AppUser> userManager,
            ILogger<OrderCheckingService> logger)
                                            : base(TimeSpan.Zero,
                                                   TimeSpan.FromMinutes(5),
                                                   logger,
                                                   nameof(OrderCheckingService))
        {
            _services = services;
            //_userManager = userManager;
            _logger = logger;
        }

        public override async Task ScheduledTask(CancellationToken cancellationToken)
        {
            try
            {
                // Initialize Services
                using var scope = _services.CreateScope();
                _orderService = scope.ServiceProvider.GetRequiredService<IOrderService>();
                _deliveryService = scope.ServiceProvider.GetRequiredService<IDeliveryService>();
                _merchantService = scope.ServiceProvider.GetRequiredService<IMerchantService>();
                _billService = scope.ServiceProvider.GetRequiredService<IBillService>();
                _balanceService = scope.ServiceProvider.GetRequiredService<IBalanceService>();
                _settingsService = scope.ServiceProvider.GetRequiredService<IGenericSettingService>();
                _uow = scope.ServiceProvider.GetRequiredService<IAppUnitOfWork>();
                appPreferences = (await _settingsService.GetValue<AppPreferences>("AppPreferences")) ?? new AppPreferences();


                await CheckRejectedOrders(cancellationToken);

                await CheckDelayedDeliveries(cancellationToken);

                //await AddBillsToCreditCardOrders(cancellationToken);
            }
            catch (Exception e)
            {
                Log(e.Message + e.StackTrace);
            }
        }

        private async Task CheckRejectedOrders(CancellationToken cancellationToken)
        {
            var rto = appPreferences.RejectedOrderReminderTimeout;

            // Check rejected orders for unnoticed notifications (+ implement admin api to handle this task)
            var rejectedOrders = await _orderService.Queryable()
                                                    .AsNoTracking()
                                                    .Include(x => x.OrderDetails)
                                                    .Where(x => x.OrderStatus == OrderStatus.Success &&
                                                                x.OrderDetails.Any(d => d.OrderDetailStatus == OrderDetailStatus.MerchantRejected &&
                                                                                        MySqlDbFunctionsExtensions.DateDiffMicrosecond(EF.Functions, d.UpdatedDate, DateTime.UtcNow) > rto))
                                                    .ToArrayAsync(cancellationToken);
            foreach (var order in rejectedOrders)
            {
                // Send SMS?
            }
        }

        private async Task CheckDelayedDeliveries(CancellationToken cancellationToken)
        {

            var ato = appPreferences.AcceptedOrderReminderTimeout;
            var delayedOrders = await _orderService.Queryable()
                                                   .AsNoTracking()
                                                   .Include(x => x.OrderDetails)
                                                   .Where(x => x.OrderStatus == OrderStatus.Success && x.DeliveryId.HasValue &&
                                                               x.OrderDetails.Any(d => d.OrderDetailStatus == OrderDetailStatus.MerchantAccepted &&
                                                                                       MySqlDbFunctionsExtensions.DateDiffMicrosecond(EF.Functions, d.UpdatedDate, DateTime.UtcNow) > ato))
                                                   .ToArrayAsync(cancellationToken);

            foreach (var order in delayedOrders)
            {
                var logs = await _orderService.GetLogs(order.Id);
                var lastShippingStarted = logs.Where(x => x.OrderDetailStatus == OrderDetailStatus.ShippingStarted)
                                              .OrderByDescending(x => x.CreatedDate)
                                              .FirstOrDefault();
                //_deliveryService.
                // Send SMS?

            }
        }

        private async Task AddBillsToCreditCardOrders(CancellationToken cancellationToken)
        {
            // IsAddedToDues

            //var ato = appPreferences.AcceptedOrderReminderTimeout;
            //var pendingBills = await _billService.Queryable()
            //                                     .AsNoTracking()
            //                                     .Where(x => !x.IsAddedToDues && x.DueDate < DateTime.UtcNow)
            //                                     .ToArrayAsync(cancellationToken);
            //
            //foreach (var bill in pendingBills)
            //{
            //    bill.IsAddedToDues = true;
            //
            //    var mUserId = await _merchantService.GetOwnerId(bill.MerchantId);
            //    var mUser = await _userManager.Users.Where(x => x.Id == mUserId).Select(x => x.FullName).FirstOrDefaultAsync();
            //    var balance = await _balanceService.GetBalance(mUserId);
            //    var oldBalance = balance?.Amount ?? 0;
            //    var oldPendingBalance = balance?.PendingAmount ?? 0;
            //    var newBalance = bill.PaymentMethod == 0 ? oldBalance - bill.MerchantAmount : oldBalance;
            //    var newPendingBalance = bill.PaymentMethod != 0 ? oldPendingBalance - bill.MerchantAmount : oldPendingBalance;
            //
            //    // Update merchant user balances
            //    await _balanceService.UpdateBalance(new BalanceDto { Amount = newBalance, PendingAmount = newPendingBalance, Id = mUserId, Name = mUser });
            //
            //
            //    //var balance = new Balance { 
            //    //    Amount = 
            //    //};
            //    //_balanceService.Update(balance);
            //}
        }

        //private async Task Initializer() {
        //
        //    using var scope = _services.CreateScope();
        //    _orderService = scope.ServiceProvider.GetRequiredService<IOrderService>();
        //    _settingsService = scope.ServiceProvider.GetRequiredService<IGenericSettingService>();
        //    _uow = scope.ServiceProvider.GetRequiredService<IAppUnitOfWork>();
        //    var appPreferences = (await _settingsService.GetValue<AppPreferences>("AppPreferences")) ?? new AppPreferences();
        //}

        private void Log(string str)
        {
            _logger.LogError(str);
        }
    }
}
