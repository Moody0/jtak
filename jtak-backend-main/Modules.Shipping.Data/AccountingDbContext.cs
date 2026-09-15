using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using App.Shared.Entities;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Modules.Accounting.Entities;
using Solf.Base;

namespace Modules.Accounting.Data
{
    public class AccountingDbContext : DbContext
        {
            private readonly IHttpContextAccessor _httpContextAccessor;
            public AccountingDbContext(DbContextOptions<AccountingDbContext> options, IHttpContextAccessor contextAccessor)
                : base(options)
            {
                _httpContextAccessor = contextAccessor;
            }

            protected override void OnModelCreating(ModelBuilder builder)
            {
                // Set Tables Prefix
                foreach (var entity in builder.Model.GetEntityTypes())
                {
                    entity.SetTableName("Accounting_" + entity.GetTableName());
                }

                foreach (var relationship in builder.Model.GetEntityTypes().SelectMany(e => e.GetForeignKeys()))
                {
                    relationship.DeleteBehavior = DeleteBehavior.Restrict;
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

                // Configure Ledger & Financial Core Entities
                builder.Entity<Account>(b =>
                {
                    b.HasIndex(a => a.AccountCode).IsUnique();
                    b.HasIndex(a => a.OwnerUserId);
                    b.HasIndex(a => a.OwnerMerchantId);
                });

                builder.Entity<JournalTransaction>(b =>
                {
                    b.HasIndex(t => t.TransactionNumber).IsUnique();
                    // A replay must never create a second financial transaction.
                    b.HasIndex(t => t.IdempotencyKey).IsUnique();
                    b.HasIndex(t => new { t.ReferenceType, t.ReferenceId });
                    b.HasMany(t => t.Entries)
                     .WithOne(e => e.Transaction)
                     .HasForeignKey(e => e.JournalTransactionId)
                     .OnDelete(DeleteBehavior.Restrict);
                });

                builder.Entity<LedgerEntry>(b =>
                {
                    b.Property(e => e.Debit).HasPrecision(18, 2);
                    b.Property(e => e.Credit).HasPrecision(18, 2);
                    b.HasIndex(e => new { e.AccountId, e.Currency });
                    b.HasOne(e => e.Account)
                     .WithMany(a => a.LedgerEntries)
                     .HasForeignKey(e => e.AccountId)
                     .OnDelete(DeleteBehavior.Restrict);
                });

                builder.Entity<DailySettlementBatch>(b =>
                {
                    b.HasIndex(s => s.BatchCode).IsUnique();
                    b.HasIndex(s => new { s.CaptainUserId, s.BatchDate });
                    b.Property(s => s.TotalCashCollected).HasPrecision(18, 2);
                    b.Property(s => s.TotalWagesEarned).HasPrecision(18, 2);
                    b.Property(s => s.NetCashRemitted).HasPrecision(18, 2);
                    b.Property(s => s.DiscrepancyAmount).HasPrecision(18, 2);
                });

                builder.Entity<SettlementRequest>(b =>
                {
                    b.HasIndex(s => s.RequestNumber).IsUnique();
                    b.HasIndex(s => new { s.PartyType, s.Status, s.CreatedDate });
                    b.HasIndex(s => new { s.RequestedByUserId, s.Status });
                    b.Property(s => s.Amount).HasPrecision(18, 2);
                    b.HasMany(s => s.MerchantAllocations)
                     .WithOne(a => a.SettlementRequest)
                     .HasForeignKey(a => a.SettlementRequestId)
                     .OnDelete(DeleteBehavior.Restrict);
                });

                builder.Entity<SettlementRequestMerchantAllocation>(b =>
                {
                    b.HasIndex(a => new { a.MerchantId, a.SettlementRequestId });
                    b.Property(a => a.Amount).HasPrecision(18, 2);
                });

                builder.Entity<Bill>(b =>
                {
                    b.HasIndex(x => new { x.OrderId, x.MerchantId }).IsUnique();
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
            public DbSet<Bill> Bills { get; set; }
            public DbSet<Payment> Payments { get; set; }
            public DbSet<Balance> Balances { get; set; }
            public DbSet<Account> Accounts { get; set; }
            public DbSet<JournalTransaction> JournalTransactions { get; set; }
            public DbSet<LedgerEntry> LedgerEntries { get; set; }
            public DbSet<DailySettlementBatch> DailySettlementBatches { get; set; }
            public DbSet<SettlementRequest> SettlementRequests { get; set; }
            public DbSet<SettlementRequestMerchantAllocation> SettlementRequestMerchantAllocations { get; set; }
        }
    }
