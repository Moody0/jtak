using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Solf.Base;
using Modules.Catalog.Entities;
using Modules.Catalog.Entities.EAV;
using App.Shared.Entities;

namespace App.Catalog.Data
{
    public class CatalogDbContext : DbContext
    {
        private readonly IHttpContextAccessor _httpContextAccessor;
        public CatalogDbContext(DbContextOptions<CatalogDbContext> options, IHttpContextAccessor contextAccessor)
            : base(options)
        {
            _httpContextAccessor = contextAccessor;
        }

        protected override void OnModelCreating(ModelBuilder builder)
        {
            // Set Tables Prefix
            foreach (var entity in builder.Model.GetEntityTypes())
            {
                var currentName = entity.GetTableName();
                if (!currentName.StartsWith("Catalog_"))
                {
                    entity.SetTableName("Catalog_" + currentName);
                }
            }

            foreach (var relationship in builder.Model.GetEntityTypes().SelectMany(e => e.GetForeignKeys()))
            {
                relationship.DeleteBehavior = DeleteBehavior.Restrict;
            }

            builder.Entity<ProductCategory>().HasIndex(b => b.Order);

            builder.Entity<Merchant>().ToTable("Catalog_Merchant");
            builder.Entity<Merchant>().HasIndex(b => b.Lat);
            builder.Entity<Merchant>().HasIndex(b => b.Lng);

            builder.Entity<ProductTag>().HasKey(c => new { c.ProductId, c.TagId });

            builder.Entity<MerchantProduct>().ToTable("Catalog_MerchantProduct");
            builder.Entity<MerchantProduct>().HasKey(c => new { c.MerchantId, c.ProductId });
            builder.Entity<MerchantProduct>().HasOne(x => x.Merchant).WithMany(x => x.MerchantProducts).HasForeignKey(x => x.MerchantId);
            builder.Entity<MerchantProduct>().HasOne(x => x.Product).WithMany(x => x.MerchantProducts).HasForeignKey(x => x.ProductId);

            builder.Entity<ProductBatch>().HasIndex(b => b.ProductId);
            builder.Entity<ProductBatch>().HasIndex(b => b.MerchantId);
            builder.Entity<ProductBatch>().HasIndex(b => b.Barcode);
            builder.Entity<ProductBatch>().HasIndex(b => b.BatchNumber);
            builder.Entity<ProductBatch>().HasIndex(b => b.ExpirationDate);
            builder.Entity<ProductBatch>().HasOne(b => b.Product).WithMany().HasForeignKey(b => b.ProductId).IsRequired(false);
            builder.Entity<ProductBatch>().HasOne(b => b.Merchant).WithMany().HasForeignKey(b => b.MerchantId).IsRequired(false);

            builder.Entity<BatchReservation>().HasIndex(b => b.OrderId);
            builder.Entity<BatchReservation>().HasIndex(b => b.OrderDetailId);
            builder.Entity<BatchReservation>().HasIndex(b => b.ProductBatchId);

            builder.Entity<DynamicFieldValue>().HasKey(c => new { c.DynamicFieldId, c.ProductId });

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
        public DbSet<Merchant> Merchants { get; set; }
        public DbSet<MerchantProduct> MerchantProducts { get; set; }
        public DbSet<ProductCategory> ProductCategories { get; set; }
        public DbSet<Product> Products { get; set; }
        public DbSet<ProductTag> ProductTags { get; set; }
        public DbSet<Tag> Tags { get; set; }
        public DbSet<ProductBatch> ProductBatches { get; set; }
        public DbSet<BatchReservation> BatchReservations { get; set; }
    }
}
