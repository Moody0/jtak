using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using App.ApiModels;
using App.Shared.Data.App;
using App.Shared.Entities;
using App.Shared.Entities.Domain;
using App.Shared.Entities.Enums;
using App.Shared.Services;
using Microsoft.EntityFrameworkCore;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using Modules.Accounting.Services;

namespace App.Services
{
    public interface IErrandSettlementService
    {
        Task<ErrandSettlementResult> RecordPurchaseAsync(SupportMessage request, decimal cost, string receiptReference, string receiptPhotoToken = null, Guid? actorUserId = null, string actorRole = "Admin");
        Task<ErrandSettlementResult> RecordDeliveryAsync(SupportMessage request, decimal collectedAmount, string deliveryCode,
            bool customerReceived, bool cashCollected, Guid? actorUserId = null, string actorRole = "Admin");
        Task<ErrandSettlementResult> ReportUnavailableAsync(SupportMessage request, string reason, Guid actorUserId);
    }

    public sealed class ErrandSettlementResult
    {
        public bool Success { get; init; }
        public bool Conflict { get; init; }
        public string Error { get; init; }
        public static ErrandSettlementResult Ok() => new() { Success = true };
        public static ErrandSettlementResult Bad(string error) => new() { Error = error };
        public static ErrandSettlementResult Stale(string error) => new() { Conflict = true, Error = error };
    }

    /// <summary>Shared, idempotent accounting transitions for admin recovery and driver actions.</summary>
    public sealed class ErrandSettlementService : IErrandSettlementService
    {
        private readonly AppDbContext _app;
        private readonly AccountingDbContext _accounting;
        private readonly ILedgerService _ledger;
        private readonly INotificationService _notifications;
        private readonly DriverFinancialSafetyService _safety;

        public ErrandSettlementService(AppDbContext app, AccountingDbContext accounting,
            ILedgerService ledger, INotificationService notifications, DriverFinancialSafetyService safety = null)
        { _app = app; _accounting = accounting; _ledger = ledger; _notifications = notifications;
          _safety = safety ?? new DriverFinancialSafetyService(accounting, ledger, app); }

        public Task<ErrandSettlementResult> RecordPurchaseAsync(SupportMessage request, decimal cost, string receiptReference, string receiptPhotoToken = null, Guid? actorUserId = null, string actorRole = "Admin") =>
            request.ErrandDriverUserId.HasValue
                ? _safety.WithDriverLockAsync(request.ErrandDriverUserId.Value, async () => {
                    await _app.Entry(request).ReloadAsync();
                    return await RecordPurchaseCoreAsync(request, cost, receiptReference, receiptPhotoToken, actorUserId, actorRole);
                })
                : Task.FromResult(ErrandSettlementResult.Stale("لم يُعيّن مندوب لهذا الطلب."));

        private async Task<ErrandSettlementResult> RecordPurchaseCoreAsync(SupportMessage request, decimal cost, string receiptReference, string receiptPhotoToken, Guid? actorUserId, string actorRole)
        {
            if (request.ErrandStatus == ErrandStatus.Purchased && request.ErrandPurchaseCost == cost)
            {
                // Attach missing receipt evidence after purchase without posting
                // another accounting transaction. Keep the first photo on retries.
                var changed = false;
                if (!string.IsNullOrWhiteSpace(receiptPhotoToken) &&
                    string.IsNullOrWhiteSpace(request.ErrandReceiptPhotoToken))
                {
                    request.ErrandReceiptPhotoToken = receiptPhotoToken;
                    changed = true;
                }
                if (!string.IsNullOrWhiteSpace(receiptReference) &&
                    string.IsNullOrWhiteSpace(request.ErrandReceiptReference))
                {
                    request.ErrandReceiptReference = receiptReference.Trim();
                    changed = true;
                }
                if (changed)
                {
                    Track(request.Id, request.ErrandStatus, request.ErrandStatus.Value,
                        actorUserId, actorRole, "تم إرفاق مستندات فاتورة الشراء");
                    try { await _app.SaveChangesAsync(); }
                    catch (DbUpdateConcurrencyException)
                    { return ErrandSettlementResult.Stale("تغيرت بيانات الطلب. حدّث القائمة قبل إعادة المحاولة."); }
                }
                return ErrandSettlementResult.Ok();
            }
            if ((request.ErrandStatus != ErrandStatus.Assigned && request.ErrandStatus != ErrandStatus.PurchasePending) || request.ErrandDriverUserId == null)
                return ErrandSettlementResult.Stale("الطلب لم يعد بانتظار الشراء.");
            if (!ValidMoney(cost) || cost > request.ErrandItemPrice ||
                (string.IsNullOrWhiteSpace(receiptReference) && string.IsNullOrWhiteSpace(receiptPhotoToken)) ||
                (receiptReference?.Trim().Length ?? 0) > 200)
                return ErrandSettlementResult.Bad("أدخل تكلفة شراء صالحة ورقم إيصال أو صورة فاتورة؛ لا يمكن أن تتجاوز التكلفة السعر المعتمد.");
            // A retry may upload the same receipt again and receive a new file token.
            // Keep the amount stable (the ledger idempotency key is per request), but
            // allow fresh receipt evidence so network retries can finish the transition.
            if (request.ErrandStatus == ErrandStatus.PurchasePending && request.ErrandPurchaseCost != cost)
                return ErrandSettlementResult.Stale("توجد محاولة شراء بمبلغ مختلف. حدّث الطلب وتواصل مع الإدارة.");

            var key = $"ErrandPurchase-{request.Id}";
            var postedCost = await PostedPurchaseCost(key);
            if (postedCost.HasValue && postedCost.Value != cost)
                return ErrandSettlementResult.Stale("سُجل مبلغ شراء مختلف في المحاسبة. راجع الإدارة.");
            var floatAccount = await _ledger.GetOrCreateUserAccountAsync(request.ErrandDriverUserId.Value, AccountType.Asset,
                SystemAccountCodes.CaptainCashFloatPrefix, "Cash Float - Errand Driver");
            if (!postedCost.HasValue) {
                var cash = await _safety.GetPositionAsync(request.ErrandDriverUserId.Value, excludeErrandId: request.Id);
                if (cash.SpendableCash < cost)
                    return ErrandSettlementResult.Bad("عهدة المندوب المتاحة لا تكفي للشراء بعد حجز مبالغ الطلبات والتسويات الأخرى. تواصل مع الإدارة.");
            }
            var goods = await _ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.ErrandGoodsInTransit,
                "Errand Goods In Transit", AccountType.Asset);
            if (request.ErrandStatus == ErrandStatus.Assigned)
            {
                var fromStatus = request.ErrandStatus;
                request.ErrandPurchaseCost = cost;
                request.ErrandReceiptReference = receiptReference?.Trim();
                request.ErrandReceiptPhotoToken = receiptPhotoToken;
                request.ErrandStatus = ErrandStatus.PurchasePending;
                Track(request.Id, fromStatus, request.ErrandStatus.Value, actorUserId, actorRole, "بدأ تسجيل الشراء");
                try { await _app.SaveChangesAsync(); }
                catch (DbUpdateConcurrencyException) { return ErrandSettlementResult.Stale("تغيرت حالة الطلب. حدّث القائمة."); }
            }
            await _ledger.PostTransactionAsync(new PostTransactionRequest
            {
                ReferenceType = "ErrandPurchase", ReferenceId = request.Id.ToString(), IdempotencyKey = key,
                Description = $"Errand #{request.Id} purchase from company driver float",
                Entries = new List<PostLedgerEntryRequest>
                {
                    new() { AccountId = goods.Id, Debit = cost, Memo = $"Errand #{request.Id} purchased goods" },
                    new() { AccountId = floatAccount.Id, Credit = cost, Memo = $"Errand #{request.Id} purchase from driver float" }
                }
            });
            if (await PostedPurchaseCost(key) != cost)
                return ErrandSettlementResult.Stale("تعذر تأكيد قيد الشراء. حدّث الطلب وتواصل مع الإدارة.");
            var purchaseFromStatus = request.ErrandStatus;
            request.ErrandPurchaseCost = cost;
            request.ErrandReceiptReference = receiptReference?.Trim();
            request.ErrandReceiptPhotoToken = receiptPhotoToken ?? request.ErrandReceiptPhotoToken;
            request.ErrandPurchasedAt = DateTime.UtcNow;
            request.ErrandStatus = ErrandStatus.Purchased;
            Track(request.Id, purchaseFromStatus, request.ErrandStatus.Value, actorUserId, actorRole, "تم توثيق الشراء وإرسال الفاتورة");
            try { await _app.SaveChangesAsync(); }
            catch (DbUpdateConcurrencyException) { return ErrandSettlementResult.Stale("سُجل الشراء لكن تعذر تحديث الحالة. حدّث الطلب."); }
            await NotifyCustomer(request, $"غرض طلبات #{request.Id} في الطريق", "تم شراء الغرض. افتح صفحة طلبات لرؤية رمز التسليم.");
            return ErrandSettlementResult.Ok();
        }

        public Task<ErrandSettlementResult> RecordDeliveryAsync(SupportMessage request, decimal collectedAmount,
            string deliveryCode, bool customerReceived, bool cashCollected, Guid? actorUserId = null, string actorRole = "Admin") =>
            request.ErrandDriverUserId.HasValue
                ? _safety.WithDriverLockAsync(request.ErrandDriverUserId.Value, async () => {
                    await _app.Entry(request).ReloadAsync();
                    return await RecordDeliveryCoreAsync(request, collectedAmount, deliveryCode, customerReceived, cashCollected, actorUserId, actorRole);
                })
                : Task.FromResult(ErrandSettlementResult.Stale("لم يُعيّن مندوب لهذا الطلب."));

        private async Task<ErrandSettlementResult> RecordDeliveryCoreAsync(SupportMessage request, decimal collectedAmount,
            string deliveryCode, bool customerReceived, bool cashCollected, Guid? actorUserId, string actorRole)
        {
            if (request.ErrandStatus == ErrandStatus.Delivered) return ErrandSettlementResult.Ok();
            if ((request.ErrandStatus != ErrandStatus.Purchased && request.ErrandStatus != ErrandStatus.DeliveryPending) ||
                request.ErrandDriverUserId == null || request.ErrandPurchaseCost == null)
                return ErrandSettlementResult.Stale("يجب تسجيل الشراء قبل تأكيد التسليم.");
            var total = request.ErrandItemPrice.GetValueOrDefault() + request.ErrandDeliveryFee.GetValueOrDefault();
            var driverEarning = request.ErrandDriverEarning ?? request.ErrandDeliveryFee.GetValueOrDefault();
            if (driverEarning < 0m || driverEarning > 1000000000m || decimal.Round(driverEarning, 2) != driverEarning)
                return ErrandSettlementResult.Stale("أجر المندوب المسجل غير صالح. أوقف التسوية وراجع الإدارة.");
            if (!customerReceived || !cashCollected || collectedAmount != total ||
                string.IsNullOrEmpty(request.ErrandDeliveryCode) || deliveryCode != request.ErrandDeliveryCode)
                return ErrandSettlementResult.Bad("تأكد من استلام العميل للمشتريات وتحصيل المبلغ الكامل، ثم أدخل الرمز الذي أعطاك إياه العميل.");

            if (request.ErrandStatus == ErrandStatus.Purchased)
            {
                var fromStatus = request.ErrandStatus;
                request.ErrandStatus = ErrandStatus.DeliveryPending;
                Track(request.Id, fromStatus, request.ErrandStatus.Value, actorUserId, actorRole, "بدأ تسجيل التسليم والتحصيل");
                try { await _app.SaveChangesAsync(); }
                catch (DbUpdateConcurrencyException) { return ErrandSettlementResult.Stale("تغيرت حالة الطلب. حدّث القائمة."); }
            }
            await ErrandDeliveryPosting.PostAsync(_ledger, request.Id, request.ErrandDriverUserId.Value,
                request.ErrandItemPrice.GetValueOrDefault(), request.ErrandDeliveryFee.GetValueOrDefault(),
                request.ErrandPurchaseCost.Value, driverEarning);
            var deliveryFromStatus = request.ErrandStatus;
            request.ErrandCashCollected = total;
            request.ErrandDeliveryCodeFailedAttempts = 0;
            request.ErrandDeliveredAt = DateTime.UtcNow;
            request.ErrandStatus = ErrandStatus.Delivered;
            Track(request.Id, deliveryFromStatus, request.ErrandStatus.Value, actorUserId, actorRole, "تم تأكيد الرمز والتحصيل");
            request.Status = SupportMessageStatus.Resolved;
            request.ResolvedDate = DateTime.UtcNow;
            try { await _app.SaveChangesAsync(); }
            catch (DbUpdateConcurrencyException) { return ErrandSettlementResult.Stale("سُجل التحصيل. حدّث الطلب للتحقق من حالته."); }
            await NotifyCustomer(request, $"تم توصيل طلبات #{request.Id}", "تم توصيل طلبك وتسجيل المبلغ المعتمد. شكراً لاستخدامك جيتك.");
            return ErrandSettlementResult.Ok();
        }

        public async Task<ErrandSettlementResult> ReportUnavailableAsync(SupportMessage request, string reason, Guid actorUserId)
        {
            if (request.ErrandStatus == ErrandStatus.Unavailable) return ErrandSettlementResult.Ok();
            if (request.ErrandStatus != ErrandStatus.Assigned || request.ErrandDriverUserId != actorUserId)
                return ErrandSettlementResult.Stale("لا يمكن الإبلاغ عن عدم التوفر في حالة الطلب الحالية.");
            if (string.IsNullOrWhiteSpace(reason) || reason.Trim().Length > 500)
                return ErrandSettlementResult.Bad("اكتب سبب عدم توفر الغرض.");
            var fromStatus = request.ErrandStatus;
            request.ErrandUnavailableReason = reason.Trim();
            request.ErrandStatus = ErrandStatus.Unavailable;
            Track(request.Id, fromStatus, request.ErrandStatus.Value, actorUserId, "Delivery", request.ErrandUnavailableReason);
            try { await _app.SaveChangesAsync(); }
            catch (DbUpdateConcurrencyException) { return ErrandSettlementResult.Stale("تغيرت حالة الطلب. حدّث القائمة."); }
            await NotifyCustomer(request, $"تعذر شراء غرض طلبات #{request.Id}",
                "تعذر العثور على الغرض المطلوب. تواصل مع الإدارة لمتابعة طلبك أو إلغائه.");
            return ErrandSettlementResult.Ok();
        }

        private Task<decimal?> PostedPurchaseCost(string key) => _accounting.JournalTransactions.AsNoTracking()
            .Include(x => x.Entries).ThenInclude(x => x.Account).Where(x => x.IdempotencyKey == key)
            .SelectMany(x => x.Entries).Where(x => x.Account.AccountCode == SystemAccountCodes.ErrandGoodsInTransit)
            .Select(x => (decimal?)x.Debit).FirstOrDefaultAsync();

        private void Track(int id, ErrandStatus? from, ErrandStatus to, Guid? actorUserId, string actorRole, string note) =>
            _app.ErrandStatusEvents.Add(new ErrandStatusEvent
            {
                SupportMessageId = id, FromStatus = from.HasValue ? (int)from.Value : (int?)null,
                ToStatus = (int)to, ActorUserId = actorUserId, ActorRole = actorRole,
                Note = note, CreatedDate = DateTime.UtcNow
            });

        private async Task NotifyCustomer(SupportMessage request, string title, string message)
        {
            if (_notifications == null || !request.UserId.HasValue) return;
            try
            {
                await _notifications.SendPushNotification(new Notification
                { TitleAr = title, TitleEn = title, TitleTr = title, TextAr = message, TextEn = message, TextTr = message,
                    NotificationType = NotificationType.Order, EntityData = $"ErrandRequest:{request.Id}" }, new[] { request.UserId.Value });
            }
            catch { /* A failed push must not undo a committed order transition. */ }
        }

        private static bool ValidMoney(decimal value) => value > 0 && value <= 1000000000m && decimal.Round(value, 2) == value;
    }
}
