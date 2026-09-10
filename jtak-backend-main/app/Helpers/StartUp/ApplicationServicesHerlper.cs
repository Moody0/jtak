using App.BackgroundTasks;
using App.Catalog.Data;
using App.Data;
using App.Orders.Data;
using App.Shared.Data.App;
using App.Shared.Data.MultiContext;
using App.Shared.Services;
using App.Shared.Services.BackroundTasks;
using App.Shared.Services.Domain;
using App.Shared.Services.eCommerce;
using App.Shared.Services.Options;
using App.Shipping.Data;
using AutoMapper;
using Microsoft.AspNetCore.Hosting;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using Modules.Accounting.Data;
using Modules.Accounting.Services;
using Modules.Catalog.Services;
using Modules.Orders.Services;
using Modules.Shipping.Services;
using URF.Core.Abstractions;
using URF.Core.Abstractions.Trackable;
using URF.Core.EF;
using URF.Core.EF.Trackable;

namespace App.Helpers.StartUp
{
    public static class ApplicationServicesHerlper
    {
        public static IServiceCollection AddApplicationServices(this IServiceCollection services)
        {

            services.AddScoped<DbContext, AppDbContext>();
            services.AddScoped<IDbEncryptor, DbEncryptor>();
            services.AddScoped(typeof(IUnitOfWork<>), typeof(UnitOfWork<>));
            services.AddScoped(typeof(IRepository<>), typeof(Repository<>));
            services.AddScoped(typeof(ITrackableRepository<>), typeof(TrackableRepository<>));
            services.AddScoped(typeof(ITrackableRepository<,>), typeof(TrackableRepository<,>));

            services.AddScoped<IAppUnitOfWork, AppUnitOfWork>();
            services.AddScoped<ICatalogUnitOfWork, CatalogUnitOfWork>();
            services.AddScoped<IOrdersUnitOfWork, OrdersUnitOfWork>();
            services.AddScoped<IAccountingUnitOfWork, AccountingUnitOfWork>();
            services.AddScoped<IShippingUnitOfWork, ShippingUnitOfWork>();

            services.AddScoped<IUserService, UserService>();
            services.AddScoped<IRoleService, RoleService>();
            services.AddScoped<INotificationService, NotificationService>();
            services.AddScoped<INotificationMessageRepo, NotificationMessageRepo>();
            services.AddScoped<ISmsLogService, SmsLogService>();
            services.AddScoped<IFaqService, FaqService>();
            services.AddScoped<IGenericSettingService, GenericSettingService>();
            services.AddScoped<ISessionHelper, SessionHelper>();
            services.AddScoped<ITestimonialService, TestimonialService>();
            services.AddScoped<IProductService, ProductService>();
            services.AddScoped<IMerchantService, MerchantService>();
            services.AddScoped<IProductCategoryService, ProductCategoryService>();
            services.AddScoped<IOrderService, OrderService>();
            services.AddScoped<IOrderDetailService, OrderDetailService>();
            services.AddScoped<IDynamicFieldService, DynamicFieldService>();
            services.AddScoped<ITagService, TagService>();
            services.AddScoped<IBannerService, BannerService>();
            services.AddScoped<IAddressService, AddressService>();
            services.AddScoped<IFavoriteProductService, FavoriteProductService>();
            services.AddScoped<IProductReviewService, ProductReviewService>();
            services.AddScoped<IDeliveryService, DeliveryService>();
            services.AddScoped<IBillService, BillService>();
            services.AddScoped<IPaymentService, PaymentService>();
            services.AddScoped<IBalanceService, BalanceService>();

            // Background Service Management
            services.AddHostedService<OrderCheckingService>();
            services.AddHostedService<QueuedHostedService>();
            services.AddSingleton<IBackgroundTaskQueue>(ctx =>
            {
                //if (!int.TryParse(hostContext.Configuration["QueueCapacity"], out var queueCapacity))
                var queueCapacity = 100;
                return new BackgroundTaskQueue(queueCapacity);
            });

            services.AddSingleton(provider => new MapperConfiguration(cfg => cfg.AddProfile(new MappingProfile(provider.GetService<IWebHostEnvironment>(), provider.GetService<IOptions<SolAppOptions>>()))).CreateMapper());

            //services.AddSingleton<IBackgroundTaskQueue, BackgroundTaskQueue>();

            return services;
        }
    }
}
