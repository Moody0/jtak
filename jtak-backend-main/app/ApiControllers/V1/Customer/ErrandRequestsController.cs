using System;
using System.Linq;
using System.Net;
using System.Threading.Tasks;
using System.Text.Json;
using App.ApiModels;
using App.Shared.Data.App;
using App.Shared.Entities;
using App.Shared.Entities.Domain;
using App.Shared.Services;
using App.Shared.Services.Extentions;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using OpenIddict.Validation.AspNetCore;
using Solf.Services;

namespace App.ApiControllers.V1.Customer
{
    [Route("api/v{version:apiVersion}/Customer/[controller]")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
    [ApiVersion("1")]
    public class ErrandRequestsController : SolApiController
    {
        private const string RequestTitle = "طلبات - اطلب أي شيء";
        private readonly ISupportMessageService _supportService;
        private readonly IAppUnitOfWork _uow;
        private readonly UserManager<AppUser> _userManager;
        private readonly IEmailService _emailService;
        private readonly ILogger<ErrandRequestsController> _logger;
        private readonly AppDbContext _db;
        private readonly HomsCoverageService _coverage;

        public ErrandRequestsController(
            ISupportMessageService supportService,
            IAppUnitOfWork uow,
            UserManager<AppUser> userManager,
            IEmailService emailService,
            ILogger<ErrandRequestsController> logger,
            AppDbContext db = null, HomsCoverageService coverage = null)
        {
            _supportService = supportService;
            _uow = uow;
            _userManager = userManager;
            _emailService = emailService;
            _logger = logger;
            _db = db;
            _coverage = coverage ?? new HomsCoverageService(null);
        }

        [HttpPost]
        public async Task<ActionResult<ErrandRequestDto>> Create([FromBody] CreateErrandRequestDto model)
        {
            if (model == null || (string.IsNullOrWhiteSpace(model.Items) && (model.ItemDetails == null || model.ItemDetails.Length == 0)) ||
                string.IsNullOrWhiteSpace(model.DeliveryAddress) || model.RequestKey == Guid.Empty)
                return BadRequest(ApiErr.Create("يرجى كتابة المطلوب وعنوان التوصيل."));

            var items = (model.Items ?? string.Join("; ", (model.ItemDetails ?? Array.Empty<ErrandRequestItemDto>())
                .Where(x => x != null).Select(x => $"{x.Name} × {x.Quantity}"))).Trim();
            var pickupPlace = model.PickupPlace?.Trim() ?? "";
            var deliveryAddress = model.DeliveryAddress.Trim();
            var notes = model.Notes?.Trim();
            if (items.Length > 1000 || pickupPlace.Length > 250 ||
                deliveryAddress.Length > 500 || (notes?.Length ?? 0) > 1000)
                return BadRequest(ApiErr.Create("تفاصيل الطلب طويلة جداً. يرجى اختصار النص."));
            if ((model.PickupLatitude.HasValue != model.PickupLongitude.HasValue) ||
                (model.PickupLatitude.HasValue && (model.PickupLatitude < -90 || model.PickupLatitude > 90 || model.PickupLongitude < -180 || model.PickupLongitude > 180)))
                return BadRequest(ApiErr.Create("موقع المتجر المحدد غير صالح."));
            if (model.ItemDetails != null && model.ItemDetails.Any(x => x == null || string.IsNullOrWhiteSpace(x.Name) || x.Name.Trim().Length > 200 || x.Quantity < 1 || x.Quantity > 999 || (x.Variant?.Length ?? 0) > 300 || (x.ProductUrl?.Length ?? 0) > 1000 || !SafeProductUrl(x.ProductUrl)))
                return BadRequest(ApiErr.Create("تحقق من أسماء المنتجات وكمياتها وروابطها."));

            var user = await _userManager.GetUserAsync(User);
            if (user == null) return Unauthorized();

            var replay = await _supportService.Queryable().AsNoTracking()
                .FirstOrDefaultAsync(x => x.ErrandRequestKey == model.RequestKey);
            if (replay != null)
                return replay.UserId == user.Id ? Ok(ToDto(replay)) : Conflict();

            try {
                var coverageError = await _coverage.ValidateAsync(model.DeliveryLat, model.DeliveryLng);
                if (coverageError != null) return BadRequest(ApiErr.Create(coverageError));
            } catch (InvalidOperationException ex) { return BadRequest(ApiErr.Create(ex.Message)); }

            var phone = string.IsNullOrWhiteSpace(model.PhoneNumber)
                ? user.PhoneNumber
                : model.PhoneNumber.Trim();
            var digits = new string((phone ?? "").Where(char.IsDigit).ToArray());
            if (digits.Length < 9 || digits.Length > 15 || (phone ?? "").Length > 50)
                return BadRequest(ApiErr.Create("يرجى إدخال رقم هاتف صالح للتواصل بخصوص الطلب."));

            var name = $"{user.FirstName} {user.LastName}".Trim();
            if (string.IsNullOrWhiteSpace(name)) name = user.FullName;
            if (string.IsNullOrWhiteSpace(name)) name = "عميل جيتك";

            var productLinks = model.ItemDetails == null ? "" : string.Join("\n", model.ItemDetails
                .Where(x => !string.IsNullOrWhiteSpace(x.ProductUrl))
                .Select(x => $"رابط {x.Name.Trim()}: {x.ProductUrl.Trim()}"));
            var message = $"المطلوب: {items}\n" +
                          (string.IsNullOrWhiteSpace(productLinks) ? "" : productLinks + "\n") +
                          (string.IsNullOrWhiteSpace(pickupPlace) ? "" : $"مكان الشراء: {pickupPlace}\n") +
                          (model.PickupLatitude.HasValue ? $"موقع المتجر: https://www.google.com/maps?q={model.PickupLatitude.Value.ToString(System.Globalization.CultureInfo.InvariantCulture)},{model.PickupLongitude.Value.ToString(System.Globalization.CultureInfo.InvariantCulture)}\n" : "") +
                          $"عنوان التوصيل: {deliveryAddress}\n" +
                          $"موقع التوصيل على الخريطة: https://www.google.com/maps?q={model.DeliveryLat.ToString(System.Globalization.CultureInfo.InvariantCulture)},{model.DeliveryLng.ToString(System.Globalization.CultureInfo.InvariantCulture)}" +
                          (string.IsNullOrWhiteSpace(notes) ? "" : $"\nملاحظات: {notes}") +
                          "\nسيظهر عرض السعر وأجرة التوصيل داخل التطبيق للموافقة قبل التنفيذ؛ الدفع نقداً عند الاستلام.";

            var request = new SupportMessage
            {
                UserId = user.Id,
                SenderName = name,
                SenderPhone = phone,
                SenderEmail = user.Email,
                Title = RequestTitle,
                Message = message,
                Status = SupportMessageStatus.New,
                ErrandRequestKey = model.RequestKey,
                ErrandStatus = ErrandStatus.Submitted,
                ErrandItemsJson = model.ItemDetails == null ? null : JsonSerializer.Serialize(model.ItemDetails),
                ErrandPickupPlace = pickupPlace,
                ErrandPickupLatitude = model.PickupLatitude,
                ErrandPickupLongitude = model.PickupLongitude,
                CreatedDate = DateTime.UtcNow
            };

            _supportService.Insert(request);
            try
            {
                await _uow.SaveChangesAsync();
            }
            catch (DbUpdateException)
            {
                var existing = await _supportService.Queryable().AsNoTracking()
                    .FirstOrDefaultAsync(x => x.ErrandRequestKey == model.RequestKey);
                if (existing == null) throw;
                return existing.UserId == user.Id ? Ok(ToDto(existing)) : Conflict();
            }
            if (_db != null)
            {
                TrackStatus(request, null, ErrandStatus.Submitted, user.Id, "Customer", null);
                await _db.SaveChangesAsync();
            }

            try
            {
                if (_emailService != null)
                    await _emailService.SendContactMessage(
                        WebUtility.HtmlEncode(name), RequestTitle,
                        WebUtility.HtmlEncode(user.Email),
                        WebUtility.HtmlEncode(message).Replace("\n", "<br/>"),
                        null, WebUtility.HtmlEncode(phone));
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to email errand request #{RequestId}; it remains in the support queue.", request.Id);
            }

            return Ok(ToDto(request));
        }

        [HttpGet]
        public async Task<ActionResult<ErrandRequestDto[]>> List()
        {
            var user = await _userManager.GetUserAsync(User);
            if (user == null) return Unauthorized();

            var requests = await _supportService.Queryable().AsNoTracking()
                .Where(x => x.UserId == user.Id && x.Title == RequestTitle)
                .OrderByDescending(x => x.CreatedDate)
                .Take(50)
                .ToArrayAsync();
            var dtos = requests.Select(ToDto).ToArray();
            await AttachStatusEvents(dtos);
            return dtos;
        }

        [HttpGet("{id:int}")]
        public async Task<ActionResult<ErrandRequestDto>> Get(int id)
        {
            var user = await _userManager.GetUserAsync(User);
            if (user == null) return Unauthorized();

            var request = await _supportService.Queryable().AsNoTracking()
                .FirstOrDefaultAsync(x => x.Id == id && x.UserId == user.Id && x.Title == RequestTitle);
            if (request == null) return NotFound();
            var dto = ToDto(request);
            await AttachStatusEvents(new[] { dto });
            return dto;
        }

        [HttpPost("{id:int}/approve")]
        public async Task<ActionResult<ErrandRequestDto>> Approve(int id, [FromBody] ApproveErrandQuoteDto model)
        {
            var user = await _userManager.GetUserAsync(User);
            if (user == null) return Unauthorized();
            var request = await _supportService.Queryable()
                .FirstOrDefaultAsync(x => x.Id == id && x.UserId == user.Id && x.Title == RequestTitle);
            if (request == null) return NotFound();
            if (request.ErrandStatus == ErrandStatus.Approved) return Ok(ToDto(request));
            if (model == null || model.QuoteKey == Guid.Empty || model.QuoteKey != request.ErrandQuoteKey)
                return Conflict(ApiErr.Create("تغير عرض السعر. حدّث الطلب وراجع المبلغ الجديد قبل الموافقة."));
            if (request.ErrandStatus != ErrandStatus.Quoted ||
                request.ErrandQuoteExpiresAt <= DateTime.UtcNow ||
                request.ErrandItemPrice == null || request.ErrandDeliveryFee == null)
                return BadRequest(ApiErr.Create("عرض السعر غير متاح أو انتهت صلاحيته. اطلب عرضاً جديداً من الدعم."));
            var fromStatus = request.ErrandStatus;
            request.ErrandStatus = ErrandStatus.Approved;
            TrackStatus(request, fromStatus, request.ErrandStatus.Value, user.Id, "Customer", "وافق العميل على عرض السعر");
            request.ErrandApprovedAt = DateTime.UtcNow;
            try { await _uow.SaveChangesAsync(); }
            catch (DbUpdateConcurrencyException)
            { return Conflict(ApiErr.Create("تغير عرض السعر. حدّث الطلب وراجع المبلغ الجديد قبل الموافقة.")); }
            return Ok(ToDto(request));
        }

        [HttpPost("{id:int}/decline")]
        public async Task<ActionResult<ErrandRequestDto>> Decline(int id)
        {
            var user = await _userManager.GetUserAsync(User);
            if (user == null) return Unauthorized();
            var request = await _supportService.Queryable()
                .FirstOrDefaultAsync(x => x.Id == id && x.UserId == user.Id && x.Title == RequestTitle);
            if (request == null) return NotFound();
            if (request.ErrandStatus == ErrandStatus.Declined) return Ok(ToDto(request));
            if (request.ErrandStatus != ErrandStatus.Quoted)
                return BadRequest(ApiErr.Create("لم يعد ممكناً رفض هذا العرض بعد بدء التنفيذ."));
            var fromStatus = request.ErrandStatus;
            request.ErrandStatus = ErrandStatus.Declined;
            TrackStatus(request, fromStatus, request.ErrandStatus.Value, user.Id, "Customer", "رفض العميل عرض السعر");
            try { await _uow.SaveChangesAsync(); }
            catch (DbUpdateConcurrencyException)
            { return Conflict(ApiErr.Create("تغيرت حالة الطلب. حدّث الصفحة وحاول مجدداً.")); }
            return Ok(ToDto(request));
        }

        [HttpPost("{id:int}/cancel")]
        public async Task<ActionResult<ErrandRequestDto>> Cancel(int id)
        {
            var user = await _userManager.GetUserAsync(User);
            if (user == null) return Unauthorized();
            var request = await _supportService.Queryable()
                .FirstOrDefaultAsync(x => x.Id == id && x.UserId == user.Id && x.Title == RequestTitle);
            if (request == null) return NotFound();
            if (request.ErrandStatus == ErrandStatus.Cancelled) return Ok(ToDto(request));
            if (request.ErrandStatus != ErrandStatus.Submitted &&
                request.ErrandStatus != ErrandStatus.Quoted &&
                request.ErrandStatus != ErrandStatus.Approved)
                return BadRequest(ApiErr.Create("بدأ تنفيذ الطلب. تواصل مع الدعم لإيقافه."));
            var fromStatus = request.ErrandStatus;
            request.ErrandStatus = ErrandStatus.Cancelled;
            TrackStatus(request, fromStatus, request.ErrandStatus.Value, user.Id, "Customer", "ألغى العميل الطلب");
            request.Status = SupportMessageStatus.Resolved;
            request.ResolvedDate = DateTime.UtcNow;
            try { await _uow.SaveChangesAsync(); }
            catch (DbUpdateConcurrencyException)
            { return Conflict(ApiErr.Create("تغيرت حالة الطلب. حدّث الصفحة وحاول مجدداً.")); }
            return Ok(ToDto(request));
        }

        private static ErrandRequestDto ToDto(SupportMessage request) => new ErrandRequestDto
        {
            Id = request.Id,
            Message = request.Message,
            Status = request.Status,
            ErrandStatus = request.ErrandStatus,
            ItemPrice = request.ErrandItemPrice,
            DeliveryFee = request.ErrandDeliveryFee,
            Total = request.ErrandItemPrice.HasValue && request.ErrandDeliveryFee.HasValue
                ? request.ErrandItemPrice.Value + request.ErrandDeliveryFee.Value : null,
            QuoteExpiresAt = request.ErrandQuoteExpiresAt,
            QuoteKey = request.ErrandQuoteKey,
            CashCollected = request.ErrandCashCollected,
            UnavailableReason = request.ErrandUnavailableReason,
            ItemDetails = DeserializeItems(request.ErrandItemsJson),
            StatusEvents = Array.Empty<ErrandStatusEventDto>(),
            DeliveryCode = request.ErrandStatus == ErrandStatus.Purchased ||
                request.ErrandStatus == ErrandStatus.DeliveryPending
                ? request.ErrandDeliveryCode : null,
            CreatedDate = request.CreatedDate
        };

        private static bool SafeProductUrl(string value) => string.IsNullOrWhiteSpace(value) ||
            (Uri.TryCreate(value, UriKind.Absolute, out var uri) && uri.Scheme == Uri.UriSchemeHttps);

        private static ErrandRequestItemDto[] DeserializeItems(string json)
        {
            if (string.IsNullOrWhiteSpace(json)) return Array.Empty<ErrandRequestItemDto>();
            try { return JsonSerializer.Deserialize<ErrandRequestItemDto[]>(json) ?? Array.Empty<ErrandRequestItemDto>(); }
            catch { return Array.Empty<ErrandRequestItemDto>(); }
        }

        private void TrackStatus(SupportMessage request, ErrandStatus? from, ErrandStatus to, Guid actorUserId, string role, string note)
        {
            _db?.ErrandStatusEvents.Add(new ErrandStatusEvent
            {
                SupportMessageId = request.Id, FromStatus = from.HasValue ? (int)from.Value : (int?)null,
                ToStatus = (int)to, ActorUserId = actorUserId, ActorRole = role, Note = note, CreatedDate = DateTime.UtcNow
            });
        }

        private async Task AttachStatusEvents(ErrandRequestDto[] dtos)
        {
            if (_db == null || dtos.Length == 0) return;
            var ids = dtos.Select(x => x.Id).ToArray();
            var events = await _db.ErrandStatusEvents.AsNoTracking().Where(x => ids.Contains(x.SupportMessageId))
                .OrderBy(x => x.CreatedDate).ToArrayAsync();
            foreach (var dto in dtos)
                dto.StatusEvents = events.Where(x => x.SupportMessageId == dto.Id).Select(x => new ErrandStatusEventDto
                { FromStatus = x.FromStatus, ToStatus = x.ToStatus, CreatedDate = x.CreatedDate }).ToArray();
        }
    }

    public class CreateErrandRequestDto
    {
        public Modules.Orders.Entities.CustomerDeviceLocation DeviceLocation { get; set; }
        public Guid RequestKey { get; set; }
        public string Items { get; set; }
        public string PickupPlace { get; set; }
        public string DeliveryAddress { get; set; }
        public decimal DeliveryLat { get; set; }
        public decimal DeliveryLng { get; set; }
        public string PhoneNumber { get; set; }
        public string Notes { get; set; }
        public ErrandRequestItemDto[] ItemDetails { get; set; }
        public decimal? PickupLatitude { get; set; }
        public decimal? PickupLongitude { get; set; }
    }

    public class ErrandRequestItemDto
    {
        public string Name { get; set; }
        public int Quantity { get; set; } = 1;
        public string Variant { get; set; }
        public string ProductUrl { get; set; }
    }

    public class ErrandStatusEventDto
    {
        public int? FromStatus { get; set; }
        public int ToStatus { get; set; }
        public DateTime CreatedDate { get; set; }
    }

    public class ApproveErrandQuoteDto { public Guid QuoteKey { get; set; } }

    public class ErrandRequestDto
    {
        public int Id { get; set; }
        public string Message { get; set; }
        public SupportMessageStatus Status { get; set; }
        public ErrandStatus? ErrandStatus { get; set; }
        public decimal? ItemPrice { get; set; }
        public decimal? DeliveryFee { get; set; }
        public decimal? Total { get; set; }
        public DateTime? QuoteExpiresAt { get; set; }
        public Guid? QuoteKey { get; set; }
        public decimal? CashCollected { get; set; }
        public string UnavailableReason { get; set; }
        public ErrandRequestItemDto[] ItemDetails { get; set; }
        public ErrandStatusEventDto[] StatusEvents { get; set; }
        public string DeliveryCode { get; set; }
        public DateTime CreatedDate { get; set; }
    }
}
