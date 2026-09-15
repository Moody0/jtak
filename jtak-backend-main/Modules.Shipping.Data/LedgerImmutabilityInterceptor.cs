using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Modules.Accounting.Entities;

namespace Modules.Accounting.Data
{
    public class LedgerImmutabilityInterceptor : SaveChangesInterceptor
    {
        public override InterceptionResult<int> SavingChanges(DbContextEventData eventData, InterceptionResult<int> result)
        {
            EnforceImmutability(eventData.Context);
            return base.SavingChanges(eventData, result);
        }

        public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
            DbContextEventData eventData,
            InterceptionResult<int> result,
            CancellationToken cancellationToken = default)
        {
            EnforceImmutability(eventData.Context);
            return base.SavingChangesAsync(eventData, result, cancellationToken);
        }

        private static void EnforceImmutability(DbContext context)
        {
            if (context == null) return;

            var forbiddenEntries = context.ChangeTracker.Entries()
                .Where(e => (e.Entity is LedgerEntry || e.Entity is JournalTransaction) &&
                            (e.State == EntityState.Modified || e.State == EntityState.Deleted))
                .ToList();

            if (forbiddenEntries.Any())
            {
                var violationNames = string.Join(", ", forbiddenEntries.Select(e => e.Entity.GetType().Name));
                throw new InvalidOperationException(
                    $"CRITICAL FINANCIAL SECURITY VIOLATION: Updates and Deletions are strictly prohibited on append-only financial ledger records ({violationNames}). Corrections must be executed via compensating reverse journal entries.");
            }
        }
    }
}
