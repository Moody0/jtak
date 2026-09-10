using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Solf.Base;
using Solf.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using App.Shared.Entities;
using App.Shared.Entities.Domain;

namespace App.Shared.Data.App
{
    public class AppDbContext : IdentityDbContext<AppUser, SolRole, Guid, SolUserClaim, SolUserRole, AppUserLogin, SolRoleClaim, SolUserToken>
    {
        private readonly IHttpContextAccessor _httpContextAccessor;
        public AppDbContext(DbContextOptions<AppDbContext> options,
                            IHttpContextAccessor contextAccessor)
                            : base(options)
        {
            _httpContextAccessor = contextAccessor;
        }

        protected override void OnModelCreating(ModelBuilder builder)
        {
            foreach (var relationship in builder.Model.GetEntityTypes().SelectMany(e => e.GetForeignKeys()))
            {
                relationship.DeleteBehavior = DeleteBehavior.Restrict;
            }

            builder.Entity<RolePermission>().HasKey(c => new { c.AppRoleId, c.SolPermissionKey });
            builder.Entity<FavoriteProduct>().HasKey(c => new { c.UserId, c.ProductId });
            builder.Entity<Testimonial>().HasMany(a => a.Translations).WithOne(p => p.Core).HasForeignKey(pt => pt.CoreId).OnDelete(DeleteBehavior.Cascade);

            //builder.Entity<AppUser>().ToTable("AppUser");
            //builder.Entity<SolRole>().ToTable("SolRole");            
            //builder.Entity<SolUserClaim>().ToTable("SolUserClaim");
            //builder.Entity<SolUserRole>().ToTable("SolUserRole");
            //builder.Entity<AppUserLogin>().ToTable("AppUserLogin");
            //builder.Entity<SolRoleClaim>().ToTable("SolRoleClaim");
            //builder.Entity<SolUserToken>().ToTable("SolUserToken");

            //builder.Entity<AppUserLogin>().Property(p => p.LoginProvider).HasMaxLength(380);
            //builder.Entity<AppUserLogin>().Property(p => p.ProviderKey).HasMaxLength(380);
            //
            //builder.Entity<SolUserToken>().Property(p => p.LoginProvider).HasMaxLength(375);
            //builder.Entity<SolUserToken>().Property(p => p.Name).HasMaxLength(375);
            builder.Entity<AppUserLogin>().Property(p => p.LoginProvider).HasMaxLength(300);
            builder.Entity<AppUserLogin>().Property(p => p.ProviderKey).HasMaxLength(300);
            
            builder.Entity<SolUserToken>().Property(p => p.LoginProvider).HasMaxLength(300);
            builder.Entity<SolUserToken>().Property(p => p.Name).HasMaxLength(300);


            // Workround for MySql Connector
            foreach (var property in builder.Model
                .GetEntityTypes()
                .SelectMany(t => t.GetProperties())
                .Where(p => p.ClrType == typeof(Guid) || p.ClrType == typeof(Guid?)))
            {
                property.SetColumnType("varchar(36)");
            }
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
                                                 .Where(x => x.State == EntityState.Deleted &&
                                                 x.Entity.GetType().GetInterfaces().Contains(typeof(ISoftDeleteEntity)));
            foreach (var entry in softDeleteEntries)
            {
                var entity = (ISoftDeleteEntity)entry.Entity;

                entity.DeletionDate = now;
                entity.DeletedBy = identityName;
                entry.State = EntityState.Modified;
            }
        }


        public DbSet<SmsLog> SmsLogs { get; set; }
        public DbSet<Notification> Notifications { get; set; }
        public DbSet<GenericSetting> Settings { get; set; }
        public DbSet<Faq> Faqs { get; set; }
        public DbSet<Banner> Banners { get; set; }
        public DbSet<City> Cities { get; set; }

        // Domain Entities
        public DbSet<Testimonial> Testimonials { get; set; }

        // User Data
        public DbSet<Address> Addresses { get; set; }
        public DbSet<FavoriteProduct> FavoriteProducts { get; set; }
        public DbSet<ProductReview> ProductReviews { get; set; }
    }
}
