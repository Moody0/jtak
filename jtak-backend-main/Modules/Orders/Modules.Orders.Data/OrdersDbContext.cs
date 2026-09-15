using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Solf.Base;
using App.Shared.Entities;
using Modules.Orders.Entities;

namespace App.Orders.Data
{
    public class OrdersDbContext : DbContext
    {
        private readonly IHttpContextAccessor _httpContextAccessor;
        public OrdersDbContext(DbContextOptions<OrdersDbContext> options, IHttpContextAccessor contextAccessor)
            : base(options)
        {
            _httpContextAccessor = contextAccessor;
        }

        protected override void OnModelCreating(ModelBuilder builder)
        {
            // Set Tables Prefix
            foreach (var entity in builder.Model.GetEntityTypes())
            {
                entity.SetTableName("Orders_" + entity.GetTableName());
            }

            foreach (var relationship in builder.Model.GetEntityTypes().SelectMany(e => e.GetForeignKeys()))
            {
                relationship.DeleteBehavior = DeleteBehavior.Restrict;
            }

            builder.Entity<Order>(b =>
            {
                b.Property(x => x.User).IsRequired(false);
                b.Property(x => x.DeliveryUser).IsRequired(false);
                b.Property(x => x.Description).IsRequired(false);
                b.Property(x => x.PaymentDescription).IsRequired(false);
                b.Property(x => x.Notes).IsRequired(false);
                b.Property(x => x.Address).IsRequired(false);
                b.Property(x => x.Phonenumber).IsRequired(false);
                b.Property(x => x.DeliveryOtp).IsRequired(false);
                b.Property(x => x.ProofOfDeliverySignature).IsRequired(false);
                b.Property(x => x.ProofOfDeliveryPhotoUrl).IsRequired(false);
                b.Property(x => x.DeliveryNotes).IsRequired(false);
                b.Property(x => x.CreatedBy).IsRequired(false);
                b.Property(x => x.UpdatedBy).IsRequired(false);
            });

            builder.Entity<OrderDetail>(b =>
            {
                b.Property(x => x.ProductTitle).IsRequired(false);
                b.Property(x => x.ProductUnit).IsRequired(false);
                b.Property(x => x.ProductImage).IsRequired(false);
                b.Property(x => x.MerchantTitle).IsRequired(false);
                b.Property(x => x.Warning).IsRequired(false);
                b.Property(x => x.CreatedBy).IsRequired(false);
                b.Property(x => x.UpdatedBy).IsRequired(false);
            });

            builder.Entity<OrderStatusChangeLog>(b =>
            {
                b.Property(x => x.OrdreDetails).IsRequired(false);
                b.Property(x => x.CreatedBy).IsRequired(false);
                b.Property(x => x.UpdatedBy).IsRequired(false);
            });

            #region Use updated datetime2 , decimal
            //https://stackoverflow.com/questions/43277154/entity-framework-core-setting-the-decimal-precision-and-scale-to-all-decimal-p
            //foreach (var property in builder.Model
            //    .GetEntityTypes()
            //    .SelectMany(t => t.GetProperties())
            //    .Where(p => p.ClrType == typeof(DateTime) || p.ClrType == typeof(DateTime?)))
            //{
            //    property.SetColumnType("datetime2");
            //}
            //
            //foreach (var property in builder.Model
            //    .GetEntityTypes()
            //    .SelectMany(t => t.GetProperties())
            //    .Where(p => p.ClrType == typeof(decimal) || p.ClrType == typeof(decimal?)))
            //{
            //    //var colName = property.GetColumnName(StoreObjectIdentifier.Table("Users", null));
            //    var colName = property.GetColumnName();
            //    var colType = (!colName.ToLower().Contains("price") && !colName.ToLower().Contains("discount") ? "decimal(18,9)" : "decimal(18,2)");
            //    property.SetColumnType(colType);
            //}

            #endregion

            base.OnModelCreating(builder);
        }

        #region SaveChanges Overrides
        public override int SaveChanges()
        {
            RefreshEntityFields();
            return base.SaveChanges();
        }

        public override async Task<int> SaveChangesAsync(CancellationToken cancellationToken = new CancellationToken())
        {
            RefreshEntityFields();
            return await base.SaveChangesAsync(cancellationToken);
        }
        #endregion

        private void RefreshEntityFields()
        {
            var identityName = _httpContextAccessor?.HttpContext?.User?.Identity?.Name ?? "System";
            var now = DateTime.UtcNow;

            var auditableEntries = ChangeTracker.Entries()
                                                .Where(x => (x.State == EntityState.Added || x.State == EntityState.Modified) &&
                                                x.Entity.GetType().GetInterfaces().Contains(typeof(IAuditableEntity)));

            foreach (var entry in auditableEntries)
            {
                var entity = (IAuditableEntity)entry.Entity;

                if (entry.State == EntityState.Added)
                {
                    entity.CreatedBy = identityName;
                    entity.CreatedDate = now;
                    entity.UpdatedBy = identityName;
                    entity.UpdatedDate = now;
                }
                else
                {
                    Entry(entity).Property(x => x.CreatedBy).IsModified = false;
                    Entry(entity).Property(x => x.CreatedDate).IsModified = false;
                }
                if (entry.State == EntityState.Modified)
                {
                    entity.UpdatedBy = identityName;
                    entity.UpdatedDate = now;
                }
            }


            var softDeleteEntries = ChangeTracker.Entries()
                                                 .Where(x => (x.State == EntityState.Deleted) &&
                                                 x.Entity.GetType().GetInterfaces().Contains(typeof(ISoftDeleteEntity)));
            foreach (var entry in softDeleteEntries)
            {
                var entity = (ISoftDeleteEntity)entry.Entity;

                entity.DeletionDate = now;
                entity.DeletedBy = identityName;
                entry.State = EntityState.Modified;
            }
        }

        public DbSet<GenericSetting> Settings { get; set; }

        // Domain Entities
        public DbSet<Order> Orders { get; set; }
        public DbSet<OrderDetail> OrderDetails { get; set; }
        public DbSet<OrderStatusChangeLog> OrderStatusChangeLogs { get; set; }
    }
}
