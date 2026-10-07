using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Security.Cryptography;
using System.Security.Claims;
using System.Threading.Tasks;
using App.ApiModels;
using App.Services;
using App.Shared.Data.App;
using App.Shared.Entities;
using App.Shared.Entities.Domain;
using App.Shared.Entities.Enums;
using App.Shared.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using Modules.Accounting.Services;
using Modules.Orders.Entities;
using Modules.Shipping.Services;
using OpenIddict.Validation.AspNetCore;

namespace App.ApiControllers.V1.Admin
{
    [Route("api/v{version:apiVersion}/Admin/[controller]")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme,
        Policy = App.Helpers.Authorization.DashboardAccessService.Policy)]
    [ApiVersion("1")]
    public class ErrandRequestsController : ControllerBase
    {
        private const string RequestTitle = "طلبات - اطلب أي شيء";
        private readonly AppDbContext _app;
        private readonly AccountingDbContext _accounting;
        private readonly ILedgerService _ledger;
        private readonly UserManager<AppUser> _users;
        private readonly INotificationService _notifications;
        private readonly ILogger<ErrandRequestsController> _logger;
        private readonly IErrandSettlementService _settlement;
        private readonly IAdminAuditService _audit;
        private readonly IDeliveryService _deliveryService;
        private readonly IGenericSettingService _genericSetting;
        private readonly DriverFinancialSafetyService _financialSafety;

        public ErrandRequestsController(AppDbContext app, AccountingDbContext accounting,
            ILedgerService ledger, UserManager<AppUser> users,
            INotificationService notifications, ILogger<ErrandRequestsController> logger,
            IErrandSettlementService settlement = null, IAdminAuditService audit = null,
            IDeliveryService deliveryService = null, IGenericSettingService genericSetting = null,
            DriverFinancialSafetyService financialSafety = null)
        {
            _app = app;
            _accounting = accounting;
            _ledger = ledger;
            _users = users;
            _notifications = notifications;
            _logger = logger;
            _settlement = settlement;
            _audit = audit;
            _deliveryService = deliveryService;
            _genericSetting = genericSetting;
            _financialSafety = financialSafety ?? new DriverFinancialSafetyService(accounting, ledger, app);
        }

        [HttpGet]
        public async Task<ActionResult<ErrandQueuePageDto>> List(
            [FromQuery] string bucket = "active", [FromQuery] string search = null,
            [FromQuery] int page = 1, [FromQuery] int pageSize = 25)
        {
            if (page < 1 || page > 100000 || pageSize < 1 || pageSize > 100)
                return BadRequest(ApiErr.Create("رقم الصفحة أو حجمها غير صالح."));
            var query = _app.SupportMessages.AsNoTracking().Where(x => x.ErrandStatus != null);
            query = bucket switch
            {
                "exceptions" => query.Where(x => x.ErrandStatus == ErrandStatus.Unavailable ||
                    x.ErrandStatus == ErrandStatus.PurchasePending || x.ErrandStatus == ErrandStatus.DeliveryPending ||
                    x.ErrandDeliveryCodeFailedAttempts > 0 || (x.ErrandStatus == ErrandStatus.Assigned &&
                        _app.ErrandStatusEvents.Any(e => e.SupportMessageId == x.Id && e.Note != null && e.Note.StartsWith("EXCEPTION:")))),
                "new" => query.Where(x => x.ErrandStatus == ErrandStatus.Submitted || x.ErrandStatus == ErrandStatus.Declined),
                "approved" => query.Where(x => x.ErrandStatus == ErrandStatus.Approved),
                "quoted" => query.Where(x => x.ErrandStatus == ErrandStatus.Quoted),
                "in-progress" => query.Where(x => x.ErrandStatus == ErrandStatus.Assigned ||
                    x.ErrandStatus == ErrandStatus.Purchased || x.ErrandStatus == ErrandStatus.PurchasePending ||
                    x.ErrandStatus == ErrandStatus.DeliveryPending || x.ErrandStatus == ErrandStatus.ReturnPending ||
                    x.ErrandStatus == ErrandStatus.Unavailable),
                "closed" => query.Where(x => x.ErrandStatus == ErrandStatus.Delivered ||
                    x.ErrandStatus == ErrandStatus.Cancelled || x.ErrandStatus == ErrandStatus.Returned),
                "active" => query.Where(x => x.ErrandStatus != ErrandStatus.Delivered &&
                    x.ErrandStatus != ErrandStatus.Cancelled && x.ErrandStatus != ErrandStatus.Returned),
                "all" => query,
                _ => null
            };
            if (query == null) return BadRequest(ApiErr.Create("مرشح الطلبات غير صالح."));
            search = search?.Trim();
            if (!string.IsNullOrEmpty(search))
            {
                if (search.Length > 100) return BadRequest(ApiErr.Create("عبارة البحث طويلة جداً."));
                query = query.Where(x => (x.SenderName != null && x.SenderName.Contains(search)) ||
                                         (x.SenderPhone != null && x.SenderPhone.Contains(search)) ||
                                         (x.Message != null && x.Message.Contains(search)));
            }
            var totalCount = await query.CountAsync();
            var requests = await query.OrderByDescending(x => x.CreatedDate).ThenByDescending(x => x.Id)
                .Skip((page - 1) * pageSize).Take(pageSize)
                .Select(x => new SupportMessageDto
                {
                    Id = x.Id, UserId = x.UserId, SenderName = x.SenderName,
                    SenderPhone = x.SenderPhone, SenderEmail = x.SenderEmail,
                    Title = x.Title, Message = x.Message, Status = x.Status,
                    CreatedDate = x.CreatedDate, ResolvedDate = x.ResolvedDate,
                    ErrandStatus = x.ErrandStatus, ErrandItemPrice = x.ErrandItemPrice,
                    ErrandDeliveryFee = x.ErrandDeliveryFee,
                    ErrandDriverEarning = x.ErrandDriverEarning ?? x.ErrandDeliveryFee,
                    ErrandQuoteExpiresAt = x.ErrandQuoteExpiresAt,
                    ErrandDriverUserId = x.ErrandDriverUserId,
                    ErrandPurchaseCost = x.ErrandPurchaseCost,
                    ErrandReceiptReference = x.ErrandReceiptReference,
                    ErrandReceiptPhotoToken = x.ErrandReceiptPhotoToken,
                    ErrandCashCollected = x.ErrandCashCollected,
                    ErrandRefundAmount = x.ErrandRefundAmount,
                    ErrandReturnReason = x.ErrandReturnReason,
                    ErrandUnavailableReason = x.ErrandUnavailableReason,
                    ErrandDeliveryCodeFailedAttempts = x.ErrandDeliveryCodeFailedAttempts,
                    ErrandLatestException = x.ErrandStatus == ErrandStatus.Assigned
                        ? _app.ErrandStatusEvents.Where(e => e.SupportMessageId == x.Id &&
                            e.Note != null && e.Note.StartsWith("EXCEPTION:"))
                            .OrderByDescending(e => e.CreatedDate).Select(e => e.Note).FirstOrDefault()
                        : null
                }).ToArrayAsync();
            return Ok(new ErrandQueuePageDto { Items = requests, TotalCount = totalCount });
        }

        [HttpGet("stats")]
        public async Task<ActionResult<ErrandQueueStatsDto>> Stats()
        {
            var query = _app.SupportMessages.AsNoTracking().Where(x => x.ErrandStatus != null);
            return Ok(new ErrandQueueStatsDto
            {
                New = await query.CountAsync(x => x.ErrandStatus == ErrandStatus.Submitted || x.ErrandStatus == ErrandStatus.Declined),
                Approved = await query.CountAsync(x => x.ErrandStatus == ErrandStatus.Approved),
                Quoted = await query.CountAsync(x => x.ErrandStatus == ErrandStatus.Quoted),
                InProgress = await query.CountAsync(x => x.ErrandStatus == ErrandStatus.Assigned ||
                    x.ErrandStatus == ErrandStatus.Purchased || x.ErrandStatus == ErrandStatus.PurchasePending ||
                    x.ErrandStatus == ErrandStatus.DeliveryPending || x.ErrandStatus == ErrandStatus.ReturnPending ||
                    x.ErrandStatus == ErrandStatus.Unavailable),
                Closed = await query.CountAsync(x => x.ErrandStatus == ErrandStatus.Delivered ||
                    x.ErrandStatus == ErrandStatus.Cancelled || x.ErrandStatus == ErrandStatus.Returned)
            });
        }

        [HttpGet("{id:int}")]
        public async Task<ActionResult<ErrandAdminDto>> Get(int id)
        {
            var request = await Find(id);
            return request == null ? NotFound() : Ok(ToDto(request));
        }

        [HttpGet("drivers")]
        public async Task<ActionResult<object>> Drivers()
        {
            var drivers = await _users.GetUsersInRoleAsync(AppRoleName.Delivery.ToString());
            if (_deliveryService == null) return StatusCode(503, ApiErr.Create("تعذر التحقق من حالة توفر المندوبين."));
            var available = new List<ErrandDriverAvailabilityDto>();
            foreach (var driver in drivers.Where(x => x.IsActive && x.DeletionDate == null))
            {
                var status = await _deliveryService.GetDeliveryStatus(driver.Id);
                if (!status.IsOnline) continue;
                available.Add(new ErrandDriverAvailabilityDto
                {
                    Id = driver.Id,
                    Name = driver.FullName ?? (driver.FirstName + " " + driver.LastName),
                    MaxCashFloat = driver.MaxCashFloat,
                    AvailableCashFloat = await _ledger.GetUserCashFloatBalanceAsync(driver.Id),
                    ActiveDeliveryOrders = status.PendingOrders.Where(x => x.CompletedDate == null)
                        .Select(x => x.OrderId).Distinct().Count(),
                    ActivePurchaseRequests = await _app.SupportMessages.CountAsync(x =>
                        x.ErrandDriverUserId == driver.Id && (x.ErrandStatus == ErrandStatus.Assigned ||
                        x.ErrandStatus == ErrandStatus.Purchased || x.ErrandStatus == ErrandStatus.PurchasePending ||
                        x.ErrandStatus == ErrandStatus.DeliveryPending || x.ErrandStatus == ErrandStatus.ReturnPending ||
                        x.ErrandStatus == ErrandStatus.Unavailable))
                });
            }
            return Ok(available.ToArray());
        }

        [HttpPut("{id:int}/quote")]
        public async Task<ActionResult<ErrandAdminDto>> Quote(int id, [FromBody] QuoteErrandDto model)
        {
            // Serialize quote replacements so two overlapping admin requests cannot
            // both renew the key and notify the customer.
            await using var quoteTransaction = _app.Database.IsRelational()
                ? await _app.Database.BeginTransactionAsync(IsolationLevel.Serializable)
                : null;
            var request = await Find(id);
            if (request == null) return NotFound();
            if (model == null || !ValidMoney(model.ItemPrice, positive: true) ||
                !ValidMoney(model.DeliveryFee, positive: false))
                return BadRequest(ApiErr.Create("أدخل سعر الغرض وأجرة توصيل صالحين بالليرة السورية."));
            if (request.ErrandStatus != ErrandStatus.Submitted &&
                request.ErrandStatus != ErrandStatus.Declined &&
                request.ErrandStatus != ErrandStatus.Quoted &&
                request.ErrandStatus != ErrandStatus.Unavailable)
                return Conflict(ApiErr.Create("لا يمكن تعديل السعر بعد موافقة العميل أو بدء التنفيذ."));

            if (request.ErrandStatus == ErrandStatus.Quoted &&
                request.ErrandQuoteExpiresAt.HasValue && request.ErrandQuoteExpiresAt.Value > DateTime.UtcNow)
                return Conflict(ApiErr.Create("يوجد عرض سعر صالح بانتظار موافقة العميل. لا يمكن إرسال عرض آخر قبل انتهاء صلاحيته."));

            var wageSetting = _genericSetting == null ? new ErrandDriverEarningSetting() :
                await _genericSetting.GetValue<ErrandDriverEarningSetting>(ErrandDriverEarningSetting.Key) ?? new ErrandDriverEarningSetting();
            if (!wageSetting.IsValid)
                return StatusCode(503, ApiErr.Create("إعداد أجر مندوب طلبات اطلب ما تحتاجه غير صالح. راجع إعدادات الأجور."));
            var subsidy = Math.Max(0m, wageSetting.Amount - model.DeliveryFee);
            if (subsidy > 0m && !model.AcceptDriverSubsidy)
                return BadRequest(ApiErr.Create($"أجر المندوب يتجاوز أجرة التوصيل بمقدار {subsidy:N2} ل.س. أكد قبول دعم الشركة قبل إرسال العرض."));

            var previousStatus = request.ErrandStatus;
            request.ErrandItemPrice = model.ItemPrice;
            request.ErrandDeliveryFee = model.DeliveryFee;
            request.ErrandDriverEarning = wageSetting.Amount;
            request.ErrandQuoteKey = Guid.NewGuid();
            request.ErrandQuoteExpiresAt = DateTime.UtcNow.AddHours(24);
            request.ErrandStatus = ErrandStatus.Quoted;
            TrackStatus(request, previousStatus, request.ErrandStatus.Value, subsidy > 0m
                ? $"إرسال عرض سعر؛ وافق المسؤول على دعم أجر المندوب بمقدار {subsidy:N2} ل.س قبل احتساب هامش الغرض."
                : "إرسال عرض سعر للعميل");
            request.Status = SupportMessageStatus.Read;
            ActionResult<ErrandAdminDto> saved;
            try
            {
                saved = await Save(request);
                if (saved.Result is OkObjectResult && quoteTransaction != null)
                    await quoteTransaction.CommitAsync();
            }
            catch (DbUpdateException)
            {
                return Conflict(ApiErr.Create("تم تحديث عرض السعر بالفعل. حدّث الطلب قبل إرسال عرض جديد."));
            }
            if (saved.Result is OkObjectResult && request.UserId.HasValue && _notifications != null)
            {
                try
                {
                    await _notifications.SendPushNotification(new Notification
                    {
                        TitleAr = $"عرض سعر طلبات #{id}",
                        TitleEn = $"Errand quote #{id}",
                        TitleTr = $"Talep teklifi #{id}",
                        TextAr = "افتح صفحة طلبات للموافقة على السعر قبل الشراء.",
                        TextEn = "Open Errand Requests to approve the quote before purchase.",
                        TextTr = "Satın almadan önce teklifi onaylamak için talepleri açın.",
                        NotificationType = NotificationType.Order,
                        EntityData = $"ErrandRequest:{id}"
                    }, new[] { request.UserId.Value });
                }
                catch (Exception ex)
                {
                    _logger?.LogWarning(ex, "Quote notification failed for errand #{RequestId}", id);
                }
            }
            return saved;
        }

        [HttpPut("{id:int}/assign")]
        public async Task<ActionResult<ErrandAdminDto>> Assign(int id, [FromBody] AssignErrandDto model)
        {
            var request = await Find(id);
            if (request == null) return NotFound();
            if (request.ErrandStatus != ErrandStatus.Approved)
                return Conflict(ApiErr.Create("يجب أن يوافق العميل على عرض السعر أولاً."));
            if (model == null || model.DriverUserId == Guid.Empty)
                return BadRequest(ApiErr.Create("اختر مندوب توصيل."));
            var driver = await _users.FindByIdAsync(model.DriverUserId.ToString());
            if (driver == null || !driver.IsActive || driver.DeletionDate != null ||
                !await _users.IsInRoleAsync(driver, AppRoleName.Delivery.ToString()))
                return BadRequest(ApiErr.Create("المستخدم المحدد ليس مندوب توصيل نشطاً."));
            if (_deliveryService == null || !(await _deliveryService.GetDeliveryStatus(driver.Id)).IsOnline)
                return Conflict(ApiErr.Create("المندوب غير متاح حالياً. اختر مندوباً متصلاً بالتطبيق."));

            return await _financialSafety.WithDriverLockAsync(driver.Id, async () => {
            await _app.Entry(request).ReloadAsync();
            if (request.ErrandStatus != ErrandStatus.Approved)
                return (ActionResult<ErrandAdminDto>)Conflict(ApiErr.Create("تغيرت حالة الطلب. حدّثه قبل التعيين."));
            var total = request.ErrandItemPrice.GetValueOrDefault() + request.ErrandDeliveryFee.GetValueOrDefault();
            var position = await _financialSafety.GetPositionAsync(driver.Id);
            var floatBalance = position.Cash;
            if (position.HasUnfinishedAccounting)
                return BadRequest(ApiErr.Create("لدى المندوب عمليات محاسبية لم تكتمل. أكملها قبل تعيين طلب جديد."));
            if (driver.MaxCashFloat <= 0 || total > driver.MaxCashFloat ||
                floatBalance + position.ExpectedCollections + request.ErrandDeliveryFee.GetValueOrDefault() +
                    request.ErrandItemPrice.GetValueOrDefault() > driver.MaxCashFloat)
                return BadRequest(ApiErr.Create("عهدة المندوب المتوقعة تتجاوز سقفه النقدي. سلّم العهدة أو اختر مندوباً آخر."));
            if (position.SpendableCash < request.ErrandItemPrice.GetValueOrDefault())
                return BadRequest(ApiErr.Create("رصيد عهدة المندوب المتاح لا يكفي لشراء الغرض. زِد العهدة أو اختر مندوباً آخر."));

            request.ErrandDriverUserId = driver.Id;
            request.ErrandDeliveryCode = RandomNumberGenerator.GetInt32(100000, 1000000).ToString();
            var previousStatus = request.ErrandStatus;
            request.ErrandStatus = ErrandStatus.Assigned;
            TrackStatus(request, previousStatus, request.ErrandStatus.Value, "تعيين مندوب");
            var saved = await Save(request);
            if (saved.Result is OkObjectResult && _notifications != null)
            {
                try
                {
                    await _notifications.SendPushNotification(new Notification
                    {
                        TitleAr = $"مهمة طلبات جديدة #{id}",
                        TitleEn = $"New errand assignment #{id}",
                        TitleTr = $"Yeni görev #{id}",
                        TextAr = "افتح صفحة طلبات الشراء لمراجعة الغرض ومكان الشراء ومبلغ التحصيل.",
                        TextEn = "Open Errand Assignments for pickup details and cash to collect.",
                        TextTr = "Ayrıntılar için görevler sayfasını açın.",
                        NotificationType = NotificationType.Order,
                        EntityData = $"ErrandDelivery:{id}"
                    }, new[] { driver.Id });
                }
                catch (Exception ex)
                {
                    _logger?.LogWarning(ex, "Driver assignment notification failed for errand #{RequestId}", id);
                }
            }
            return saved;
            });
        }

        [HttpPut("{id:int}/purchase")]
        public async Task<ActionResult<ErrandAdminDto>> Purchase(int id, [FromBody] PurchaseErrandDto model)
        {
            if (_settlement != null) return await PurchaseCore(id, model);
            var current = await Find(id);
            if (current == null) return NotFound();
            if (!current.ErrandDriverUserId.HasValue) return Conflict(ApiErr.Create("لم يُعيّن مندوب لهذا الطلب."));
            return await _financialSafety.WithDriverLockAsync(current.ErrandDriverUserId.Value, async () => {
                await _app.Entry(current).ReloadAsync();
                return await PurchaseCore(id, model);
            });
        }

        private async Task<ActionResult<ErrandAdminDto>> PurchaseCore(int id, PurchaseErrandDto model)
        {
            var request = await Find(id);
            if (request == null) return NotFound();
            if (_settlement != null)
            {
                var result = await _settlement.RecordPurchaseAsync(request, model?.PurchaseCost ?? 0, model?.ReceiptReference,
                    request.ErrandReceiptPhotoToken,
                    actorUserId: CurrentActorId(), actorRole: "Admin");
                if (!result.Success) return result.Conflict ? Conflict(ApiErr.Create(result.Error)) : BadRequest(ApiErr.Create(result.Error));
                return Ok(ToDto(request));
            }
            if (request.ErrandStatus == ErrandStatus.Purchased &&
                request.ErrandPurchaseCost == model?.PurchaseCost) return Ok(ToDto(request));
            if ((request.ErrandStatus != ErrandStatus.Assigned &&
                request.ErrandStatus != ErrandStatus.PurchasePending) ||
                request.ErrandDriverUserId == null)
                return Conflict(ApiErr.Create("يجب تعيين مندوب بعد موافقة العميل قبل تسجيل الشراء."));
            if (model == null || !ValidMoney(model.PurchaseCost, positive: true) ||
                model.PurchaseCost > request.ErrandItemPrice ||
                string.IsNullOrWhiteSpace(model.ReceiptReference) || model.ReceiptReference.Trim().Length > 200)
                return BadRequest(ApiErr.Create("أدخل قيمة فاتورة الشراء ورقم الإيصال؛ لا يمكن أن تتجاوز التكلفة السعر الذي وافق عليه العميل."));
            if (request.ErrandStatus == ErrandStatus.PurchasePending &&
                (request.ErrandPurchaseCost != model.PurchaseCost ||
                 request.ErrandReceiptReference != model.ReceiptReference.Trim()))
                return Conflict(ApiErr.Create("سُجلت تكلفة أو فاتورة مختلفة لمحاولة الشراء الحالية. استخدم نفس القيم أو راجع المحاسبة."));

            var key = $"ErrandPurchase-{id}";
            var postedCost = await PostedPurchaseCost(key);
            if (postedCost.HasValue && postedCost.Value != model.PurchaseCost)
                return Conflict(ApiErr.Create("تم تسجيل مبلغ شراء مختلف لهذا الطلب. راجع قيد المحاسبة."));
            var floatAccount = await _ledger.GetOrCreateUserAccountAsync(
                request.ErrandDriverUserId.Value, AccountType.Asset,
                SystemAccountCodes.CaptainCashFloatPrefix, "Cash Float - Errand Driver");
            if (!postedCost.HasValue && (await _financialSafety.GetPositionAsync(request.ErrandDriverUserId.Value, excludeErrandId: id)).SpendableCash < model.PurchaseCost)
                return BadRequest(ApiErr.Create("عهدة المندوب النقدية لا تكفي لشراء الغرض. زِد العهدة قبل التنفيذ."));
            var goods = await _ledger.GetOrCreateSystemAccountAsync(
                SystemAccountCodes.ErrandGoodsInTransit, "Errand Goods In Transit", AccountType.Asset);
            if (request.ErrandStatus == ErrandStatus.Assigned)
            {
                request.ErrandPurchaseCost = model.PurchaseCost;
                request.ErrandReceiptReference = model.ReceiptReference.Trim();
                request.ErrandStatus = ErrandStatus.PurchasePending;
                var claimed = await Save(request);
                if (claimed.Result is not OkObjectResult) return claimed;
            }
            await _ledger.PostTransactionAsync(new PostTransactionRequest
            {
                ReferenceType = "ErrandPurchase", ReferenceId = id.ToString(), IdempotencyKey = key,
                Description = $"Errand #{id} purchase from company driver float",
                Entries = new List<PostLedgerEntryRequest>
                {
                    new() { AccountId = goods.Id, Debit = model.PurchaseCost, Memo = $"Errand #{id} purchased goods" },
                    new() { AccountId = floatAccount.Id, Credit = model.PurchaseCost, Memo = $"Errand #{id} shop payment from driver float" }
                }
            });
            // The journal's unique idempotency key wins a concurrent race. A
            // second administrator may have submitted another receipt amount.
            var committedCost = await PostedPurchaseCost(key);
            if (committedCost != model.PurchaseCost)
                return Conflict(ApiErr.Create("سُجل مبلغ شراء مختلف في المحاسبة لهذا الطلب. حدّث الصفحة وراجع الإيصال."));
            request.ErrandPurchaseCost = model.PurchaseCost;
            request.ErrandReceiptReference = model.ReceiptReference.Trim();
            request.ErrandPurchasedAt = DateTime.UtcNow;
            request.ErrandStatus = ErrandStatus.Purchased;
            var saved = await Save(request);
            if (saved.Result is OkObjectResult)
                await NotifyCustomer(request, $"غرض طلبات #{id} في الطريق",
                    "افتح صفحة طلبات لرؤية رمز التسليم. أعطِ الرمز للمندوب بعد استلام الغرض فقط.");
            return saved;
        }

        [HttpPut("{id:int}/deliver")]
        public async Task<ActionResult<ErrandAdminDto>> Deliver(int id, [FromBody] DeliverErrandDto model)
        {
            if (_settlement != null) return await DeliverCore(id, model);
            var current = await Find(id);
            if (current == null) return NotFound();
            if (!current.ErrandDriverUserId.HasValue) return Conflict(ApiErr.Create("لم يُعيّن مندوب لهذا الطلب."));
            return await _financialSafety.WithDriverLockAsync(current.ErrandDriverUserId.Value, async () => {
                await _app.Entry(current).ReloadAsync();
                return await DeliverCore(id, model);
            });
        }

        private async Task<ActionResult<ErrandAdminDto>> DeliverCore(int id, DeliverErrandDto model)
        {
            var request = await Find(id);
            if (request == null) return NotFound();
            if (string.IsNullOrWhiteSpace(model?.RecoveryReason) || model.RecoveryReason.Trim().Length > 500)
                return BadRequest(ApiErr.Create("اكتب سبب استخدام إجراء التسليم الاستثنائي."));
            if (_settlement != null)
            {
                var result = await _settlement.RecordDeliveryAsync(request, model.CollectedAmount,
                    model.DeliveryCode, model.CustomerReceived, model.CashCollected, CurrentActorId(), "Admin");
                if (!result.Success) return result.Conflict ? Conflict(ApiErr.Create(result.Error)) : BadRequest(ApiErr.Create(result.Error));
                if (_audit != null)
                    await _audit.LogAsync(new AdminAuditLogEntry
                    {
                        Module = "ErrandRequests", Action = "AdminDeliveryRecovery", EntityType = "ErrandRequest",
                        EntityId = id.ToString(), Description = model.RecoveryReason.Trim(), Result = "Success"
                    });
                return Ok(ToDto(request));
            }
            if (request.ErrandStatus == ErrandStatus.Delivered) return Ok(ToDto(request));
            if ((request.ErrandStatus != ErrandStatus.Purchased &&
                request.ErrandStatus != ErrandStatus.DeliveryPending) ||
                request.ErrandDriverUserId == null ||
                request.ErrandPurchaseCost == null)
                return Conflict(ApiErr.Create("يجب تسجيل فاتورة الشراء قبل إتمام التسليم."));
            var total = request.ErrandItemPrice.GetValueOrDefault() + request.ErrandDeliveryFee.GetValueOrDefault();
            var driverEarning = request.ErrandDriverEarning ?? request.ErrandDeliveryFee.GetValueOrDefault();
            if (driverEarning < 0m || driverEarning > 1000000000m || decimal.Round(driverEarning, 2) != driverEarning)
                return Conflict(ApiErr.Create("أجر المندوب المسجل غير صالح. أوقف التسوية وراجع الإدارة."));
            if (model == null || !model.CustomerReceived || !model.CashCollected ||
                model.CollectedAmount != total ||
                string.IsNullOrEmpty(request.ErrandDeliveryCode) ||
                model.DeliveryCode != request.ErrandDeliveryCode)
                return BadRequest(ApiErr.Create("أكد الاستلام والتحصيل النقدي الكامل وأدخل رمز التسليم الذي أعطاه العميل للمندوب."));

            if (request.ErrandStatus == ErrandStatus.Purchased)
            {
                request.ErrandStatus = ErrandStatus.DeliveryPending;
                var claimed = await Save(request);
                if (claimed.Result is not OkObjectResult) return claimed;
            }
            await ErrandDeliveryPosting.PostAsync(_ledger, id, request.ErrandDriverUserId.Value,
                request.ErrandItemPrice.GetValueOrDefault(), request.ErrandDeliveryFee.GetValueOrDefault(),
                request.ErrandPurchaseCost.Value, driverEarning);
            request.ErrandCashCollected = total;
            request.ErrandDeliveredAt = DateTime.UtcNow;
            request.ErrandStatus = ErrandStatus.Delivered;
            request.Status = SupportMessageStatus.Resolved;
            request.ResolvedDate = DateTime.UtcNow;
            var saved = await Save(request);
            if (saved.Result is OkObjectResult)
                await NotifyCustomer(request, $"تم توصيل طلبات #{id}",
                    "تم توصيل طلبك وتسجيل التحصيل النقدي. شكراً لاستخدامك جيتك.");
            return saved;
        }

        [HttpPut("{id:int}/cancel")]
        public async Task<ActionResult<ErrandAdminDto>> Cancel(int id, [FromBody] CancelErrandDto model)
        {
            var request = await Find(id);
            if (request == null) return NotFound();
            if (request.ErrandStatus == ErrandStatus.Cancelled) return Ok(ToDto(request));
            if (model == null || string.IsNullOrWhiteSpace(model.Reason) || model.Reason.Trim().Length > 500)
                return BadRequest(ApiErr.Create("اكتب سبب الإلغاء."));
            if (request.ErrandStatus != ErrandStatus.Submitted &&
                request.ErrandStatus != ErrandStatus.Quoted &&
                request.ErrandStatus != ErrandStatus.Declined &&
                request.ErrandStatus != ErrandStatus.Approved &&
                request.ErrandStatus != ErrandStatus.Assigned &&
                request.ErrandStatus != ErrandStatus.Unavailable)
                return Conflict(ApiErr.Create("بعد الشراء استخدم مسار الإرجاع وتسجيل المبلغ المسترد."));
            var previousStatus = request.ErrandStatus;
            request.ErrandStatus = ErrandStatus.Cancelled;
            request.ErrandReturnReason = model.Reason.Trim();
            TrackStatus(request, previousStatus, request.ErrandStatus.Value, request.ErrandReturnReason);
            request.Status = SupportMessageStatus.Resolved;
            request.ResolvedDate = DateTime.UtcNow;
            var saved = await Save(request);
            if (saved.Result is OkObjectResult)
                await NotifyCustomer(request, $"أُلغي طلبات #{id}",
                    "أُلغي الطلب قبل الشراء. افتح صفحة طلبات للتفاصيل.");
            return saved;
        }

        [HttpPut("{id:int}/return")]
        public async Task<ActionResult<ErrandAdminDto>> Return(int id, [FromBody] ReturnErrandDto model)
        {
            
            var current = await Find(id);
            if (current == null) return NotFound();
            if (!current.ErrandDriverUserId.HasValue) return Conflict(ApiErr.Create("لم يُعيّن مندوب لهذا الطلب."));
            return await _financialSafety.WithDriverLockAsync(current.ErrandDriverUserId.Value, async () => {
                await _app.Entry(current).ReloadAsync();
                return await ReturnCore(id, model);
            });
        }

        private async Task<ActionResult<ErrandAdminDto>> ReturnCore(int id, ReturnErrandDto model)
        {
            var request = await Find(id);
            if (request == null) return NotFound();
            if (request.ErrandStatus == ErrandStatus.Returned && request.ErrandRefundAmount == model?.RefundAmount)
                return Ok(ToDto(request));
            if ((request.ErrandStatus != ErrandStatus.Purchased &&
                request.ErrandStatus != ErrandStatus.ReturnPending) ||
                request.ErrandDriverUserId == null ||
                request.ErrandPurchaseCost == null)
                return Conflict(ApiErr.Create("لا يوجد شراء معلّق يمكن إرجاعه."));
            if (model == null || !ValidMoney(model.RefundAmount, positive: false) ||
                model.RefundAmount > request.ErrandPurchaseCost ||
                string.IsNullOrWhiteSpace(model.Reason) || model.Reason.Trim().Length > 500)
                return BadRequest(ApiErr.Create("أدخل المبلغ المسترد وسبب الإرجاع؛ لا يمكن أن يزيد الاسترداد عن تكلفة الشراء."));
            if (request.ErrandStatus == ErrandStatus.ReturnPending &&
                (request.ErrandRefundAmount != model.RefundAmount ||
                 request.ErrandReturnReason != model.Reason.Trim()))
                return Conflict(ApiErr.Create("سُجل مبلغ أو سبب مختلف لمحاولة الإرجاع الحالية. استخدم نفس القيم أو راجع المحاسبة."));

            var floatAccount = await _ledger.GetOrCreateUserAccountAsync(
                request.ErrandDriverUserId.Value, AccountType.Asset,
                SystemAccountCodes.CaptainCashFloatPrefix, "Cash Float - Errand Driver");
            var goods = await _ledger.GetOrCreateSystemAccountAsync(
                SystemAccountCodes.ErrandGoodsInTransit, "Errand Goods In Transit", AccountType.Asset);
            var loss = await _ledger.GetOrCreateSystemAccountAsync(
                SystemAccountCodes.OperationalExpense, "Operational Expense", AccountType.Expense);
            var entries = new List<PostLedgerEntryRequest>
            {
                new() { AccountId = goods.Id, Credit = request.ErrandPurchaseCost.Value,
                    Memo = $"Errand #{id} goods returned or written off" }
            };
            if (model.RefundAmount > 0)
                entries.Add(new() { AccountId = floatAccount.Id, Debit = model.RefundAmount,
                    Memo = $"Errand #{id} shop refund into driver float" });
            var unrecovered = request.ErrandPurchaseCost.Value - model.RefundAmount;
            if (unrecovered > 0)
                entries.Add(new() { AccountId = loss.Id, Debit = unrecovered,
                    Memo = $"Errand #{id} unrecovered purchase cost" });
            var key = $"ErrandReturn-{id}";
            if (request.ErrandStatus == ErrandStatus.Purchased)
            {
                var fromStatus = request.ErrandStatus;
                request.ErrandRefundAmount = model.RefundAmount;
                request.ErrandReturnReason = model.Reason.Trim();
                request.ErrandStatus = ErrandStatus.ReturnPending;
                TrackStatus(request, fromStatus, request.ErrandStatus.Value, model.Reason.Trim());
                var claimed = await Save(request);
                if (claimed.Result is not OkObjectResult) return claimed;
            }
            await _ledger.PostTransactionAsync(new PostTransactionRequest
            {
                ReferenceType = "ErrandReturn", ReferenceId = id.ToString(),
                IdempotencyKey = key,
                Description = $"Errand #{id} return: {model.Reason.Trim()}", Entries = entries
            });
            var committedRefund = await _accounting.JournalTransactions.AsNoTracking()
                .Where(x => x.IdempotencyKey == key)
                .SelectMany(x => x.Entries)
                .Where(x => x.AccountId == floatAccount.Id)
                .SumAsync(x => x.Debit);
            if (committedRefund != model.RefundAmount)
                return Conflict(ApiErr.Create("تم تسجيل مبلغ استرداد مختلف في المحاسبة. حدّث الصفحة وراجع القيد."));
            var previousStatus = request.ErrandStatus;
            request.ErrandRefundAmount = model.RefundAmount;
            request.ErrandReturnReason = model.Reason.Trim();
            request.ErrandReturnedAt = DateTime.UtcNow;
            request.ErrandStatus = ErrandStatus.Returned;
            TrackStatus(request, previousStatus, request.ErrandStatus.Value, request.ErrandReturnReason);
            request.Status = SupportMessageStatus.Resolved;
            request.ResolvedDate = DateTime.UtcNow;
            var saved = await Save(request);
            if (saved.Result is OkObjectResult)
                await NotifyCustomer(request, $"تم إرجاع طلبك #{id}",
                    "تم تسجيل إرجاع الطلب والمبلغ المسترد. افتح صفحة طلبات للتفاصيل.");
            return saved;
        }

        private Task<SupportMessage> Find(int id) => _app.SupportMessages
            .FirstOrDefaultAsync(x => x.Id == id && x.Title == RequestTitle && x.ErrandStatus != null);

        private Guid? CurrentActorId()
        {
            var value = User?.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? User?.FindFirst("sub")?.Value;
            return Guid.TryParse(value, out var id) ? id : null;
        }

        private void TrackStatus(SupportMessage request, ErrandStatus? from, ErrandStatus to, string note) =>
            _app.ErrandStatusEvents.Add(new ErrandStatusEvent
            {
                SupportMessageId = request.Id, FromStatus = from.HasValue ? (int)from.Value : (int?)null,
                ToStatus = (int)to, ActorUserId = CurrentActorId(), ActorRole = "Admin",
                Note = note?.Length > 500 ? note.Substring(0, 500) : note, CreatedDate = DateTime.UtcNow
            });

        private async Task<decimal?> PostedPurchaseCost(string key)
        {
            var transaction = await _accounting.JournalTransactions.AsNoTracking()
                .Include(x => x.Entries).ThenInclude(x => x.Account)
                .FirstOrDefaultAsync(x => x.IdempotencyKey == key);
            return transaction?.Entries.FirstOrDefault(x =>
                x.Account.AccountCode == SystemAccountCodes.ErrandGoodsInTransit)?.Debit;
        }

        private async Task<ActionResult<ErrandAdminDto>> Save(SupportMessage request)
        {
            try { await _app.SaveChangesAsync(); }
            catch (DbUpdateConcurrencyException)
            { return Conflict(ApiErr.Create("تغيرت حالة الطلب أثناء التعديل. حدّث الصفحة وحاول مجدداً.")); }
            return Ok(ToDto(request));
        }

        private async Task NotifyCustomer(SupportMessage request, string title, string message)
        {
            if (_notifications == null || !request.UserId.HasValue) return;
            try
            {
                await _notifications.SendPushNotification(new Notification
                {
                    TitleAr = title, TitleEn = title, TitleTr = title,
                    TextAr = message, TextEn = message, TextTr = message,
                    NotificationType = NotificationType.Order,
                    EntityData = $"ErrandRequest:{request.Id}"
                }, new[] { request.UserId.Value });
            }
            catch (Exception ex)
            {
                _logger?.LogWarning(ex, "Errand notification failed for #{RequestId}", request.Id);
            }
        }

        private static bool ValidMoney(decimal value, bool positive) =>
            (positive ? value > 0 : value >= 0) && value <= 1000000000m &&
            decimal.Round(value, 2) == value;

        private static ErrandAdminDto ToDto(SupportMessage x) => new()
        {
            Id = x.Id, Status = x.ErrandStatus, ItemPrice = x.ErrandItemPrice,
            DeliveryFee = x.ErrandDeliveryFee,
            DriverEarning = x.ErrandDriverEarning ?? x.ErrandDeliveryFee,
            Total = x.ErrandItemPrice.HasValue && x.ErrandDeliveryFee.HasValue
                ? x.ErrandItemPrice + x.ErrandDeliveryFee : null,
            QuoteExpiresAt = x.ErrandQuoteExpiresAt, DriverUserId = x.ErrandDriverUserId,
            PurchaseCost = x.ErrandPurchaseCost, ReceiptReference = x.ErrandReceiptReference,
            ReceiptPhotoToken = x.ErrandReceiptPhotoToken,
            CashCollected = x.ErrandCashCollected, RefundAmount = x.ErrandRefundAmount,
            ReturnReason = x.ErrandReturnReason, UnavailableReason = x.ErrandUnavailableReason
        };
    }

    public class QuoteErrandDto { public decimal ItemPrice { get; set; } public decimal DeliveryFee { get; set; } public bool AcceptDriverSubsidy { get; set; } }
    public class ErrandDriverAvailabilityDto
    {
        public Guid Id { get; set; }
        public string Name { get; set; }
        public decimal MaxCashFloat { get; set; }
        public decimal AvailableCashFloat { get; set; }
        public int ActiveDeliveryOrders { get; set; }
        public int ActivePurchaseRequests { get; set; }
    }
    public class ErrandQueuePageDto
    {
        public SupportMessageDto[] Items { get; set; }
        public int TotalCount { get; set; }
    }
    public class ErrandQueueStatsDto
    {
        public int New { get; set; }
        public int Approved { get; set; }
        public int Quoted { get; set; }
        public int InProgress { get; set; }
        public int Closed { get; set; }
    }
    public class AssignErrandDto { public Guid DriverUserId { get; set; } }
    public class PurchaseErrandDto { public decimal PurchaseCost { get; set; } public string ReceiptReference { get; set; } }
    public class DeliverErrandDto { public bool CustomerReceived { get; set; } public bool CashCollected { get; set; } public decimal CollectedAmount { get; set; } public string DeliveryCode { get; set; } public string RecoveryReason { get; set; } }
    public class CancelErrandDto { public string Reason { get; set; } }
    public class ReturnErrandDto { public decimal RefundAmount { get; set; } public string Reason { get; set; } }
    public class ErrandAdminDto
    {
        public int Id { get; set; }
        public ErrandStatus? Status { get; set; }
        public decimal? ItemPrice { get; set; }
        public decimal? DeliveryFee { get; set; }
        public decimal? DriverEarning { get; set; }
        public decimal? Total { get; set; }
        public DateTime? QuoteExpiresAt { get; set; }
        public Guid? DriverUserId { get; set; }
        public decimal? PurchaseCost { get; set; }
        public string ReceiptReference { get; set; }
        public string ReceiptPhotoToken { get; set; }
        public decimal? CashCollected { get; set; }
        public decimal? RefundAmount { get; set; }
        public string ReturnReason { get; set; }
        public string UnavailableReason { get; set; }
    }
}
