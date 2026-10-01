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
            builder.Entity<Notification>(b =>
            {
                b.Property(x => x.DispatchKey).HasMaxLength(64).IsRequired(false);
                b.Property(x => x.AudienceApp).HasMaxLength(16).IsRequired(false);
                b.HasIndex(x => x.DispatchKey).IsUnique();
                b.HasIndex(x => new { x.PushSentAtUtc, x.PushNextAttemptAtUtc, x.PushLockedUntilUtc });
            });
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

            builder.Entity<AppUser>().Property(p => p.MaxCashFloat).HasColumnType("decimal(65,30)");
            builder.Entity<AppUser>().Property(p => p.CaptainRate).HasColumnType("decimal(65,30)");
            builder.Entity<SupportMessage>(b =>
            {
                b.HasIndex(x => x.ErrandRequestKey).IsUnique();
                b.Property(x => x.ErrandStatus).IsConcurrencyToken();
                b.Property(x => x.ErrandQuoteExpiresAt).IsConcurrencyToken();
                b.Property(x => x.ErrandItemPrice).HasColumnType("decimal(18,2)");
                b.Property(x => x.ErrandDeliveryFee).HasColumnType("decimal(18,2)");
                b.Property(x => x.ErrandDriverEarning).HasColumnType("decimal(18,2)");
                b.Property(x => x.ErrandPurchaseCost).HasColumnType("decimal(18,2)");
                b.Property(x => x.ErrandReceiptPhotoToken).HasMaxLength(255);
                b.Property(x => x.ErrandCashCollected).HasColumnType("decimal(18,2)");
                b.Property(x => x.ErrandRefundAmount).HasColumnType("decimal(18,2)");
                b.Property(x => x.ErrandReceiptReference).HasMaxLength(200);
                b.Property(x => x.ErrandDeliveryCode).HasMaxLength(6);
                b.Property(x => x.ErrandReturnReason).HasMaxLength(500);
                b.Property(x => x.ErrandItemsJson).HasColumnType("longtext");
                b.Property(x => x.ErrandPickupPlace).HasMaxLength(250);
                b.Property(x => x.ErrandPickupLatitude).HasColumnType("decimal(10,7)");
                b.Property(x => x.ErrandPickupLongitude).HasColumnType("decimal(10,7)");
                b.Property(x => x.ErrandUnavailableReason).HasMaxLength(500);
            });
            builder.Entity<ErrandStatusEvent>(b =>
            {
                b.HasKey(x => x.Id);
                b.HasIndex(x => new { x.SupportMessageId, x.CreatedDate });
                b.Property(x => x.ActorRole).HasMaxLength(32);
                b.Property(x => x.Note).HasMaxLength(500);
                b.HasOne<SupportMessage>().WithMany().HasForeignKey(x => x.SupportMessageId).OnDelete(DeleteBehavior.Cascade);
            });
            builder.Entity<PendingPhoneSignup>(b =>
            {
                b.HasKey(x => x.PhoneNumber);
                b.Property(x => x.PhoneNumber).HasMaxLength(16).IsRequired();
                b.Property(x => x.Code).HasMaxLength(6).IsRequired();
                b.HasIndex(x => x.ExpiresAt);
            });
            
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

            builder.Entity<AdminAuditLog>(b =>
            {
                b.HasKey(x => x.Id);
                b.Property(x => x.AdminName).HasMaxLength(200);
                b.Property(x => x.AdminEmail).HasMaxLength(200);
                b.Property(x => x.Module).HasMaxLength(100);
                b.Property(x => x.Action).HasMaxLength(100);
                b.Property(x => x.EntityType).HasMaxLength(100);
                b.Property(x => x.EntityId).HasMaxLength(200);
                b.Property(x => x.Description).HasMaxLength(2000);
                b.Property(x => x.Result).HasMaxLength(50);
                b.Property(x => x.IpAddress).HasMaxLength(100);
                b.Property(x => x.UserAgent).HasMaxLength(500);
                b.Property(x => x.CorrelationId).HasMaxLength(100);

                b.HasIndex(x => x.CreatedDate);
                b.HasIndex(x => x.AdminUserId);
                b.HasIndex(x => x.Module);
                b.HasIndex(x => x.Action);
                b.HasIndex(x => x.Result);
                b.HasIndex(x => new { x.EntityType, x.EntityId });
                b.HasIndex(x => x.CorrelationId);
            });

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
        public DbSet<PendingPhoneSignup> PendingPhoneSignups { get; set; }
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
        public DbSet<SupportMessage> SupportMessages { get; set; }
        public DbSet<ErrandStatusEvent> ErrandStatusEvents { get; set; }
        public DbSet<AdminAuditLog> AdminAuditLogs { get; set; }
    }
}
