using System;
using System.Linq;
using System.IO;
using System.Threading.Tasks;
using App.ApiModels;
using App.Helpers;
using App.Services;
using App.Shared.Data.App;
using App.Shared.Entities;
using App.Shared.Entities.Domain;
using App.Shared.Entities.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using OpenIddict.Validation.AspNetCore;

namespace App.ApiControllers.V1.Delivery
{
    [Route("api/v{version:apiVersion}/Delivery/[controller]")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme,
        Policy = nameof(AppPermissionKey.DeliveryPermission))]
    [ApiVersion("1")]
    public class ErrandRequestsController : ControllerBase
    {
        private readonly AppDbContext _db;
        private readonly UserManager<AppUser> _users;
        private readonly IWebHostEnvironment _env;
        private readonly ILogger<ErrandRequestsController> _logger;
        private readonly IErrandSettlementService _settlement;

        public ErrandRequestsController(AppDbContext db, UserManager<AppUser> users,
            IWebHostEnvironment env, ILogger<ErrandRequestsController> logger,
            IErrandSettlementService settlement = null)
        {
            _db = db;
            _users = users;
            _env = env;
            _logger = logger;
            _settlement = settlement;
        }

        // New clients record the purchase directly. The older /receipt action
        // remains available for app versions that still require admin review.
        [HttpPost("{id:int}/purchase")]
        [RequestSizeLimit(11 * 1024 * 1024)]
        public async Task<ActionResult<DriverErrandDto>> Purchase(int id, [FromForm] SubmitErrandReceiptDto model)
        {
            var driver = await _users.GetUserAsync(User);
            if (driver == null) return Unauthorized();
            var request = await _db.SupportMessages.FirstOrDefaultAsync(x =>
                x.Id == id && x.ErrandDriverUserId == driver.Id && x.ErrandStatus != null);
            if (request == null) return NotFound();
            if (_settlement == null) return StatusCode(503, ApiErr.Create("خدمة تسجيل الشراء غير متاحة حالياً."));
            if (model == null || model.PurchaseCost <= 0 || decimal.Round(model.PurchaseCost, 2) != model.PurchaseCost ||
                (model.ReceiptReference?.Trim().Length ?? 0) > 200)
                return BadRequest(ApiErr.Create("أدخل تكلفة شراء صحيحة ورقم إيصال أو صورة فاتورة."));
            if (request.ErrandItemPrice.HasValue && model.PurchaseCost > request.ErrandItemPrice.Value)
            {
                if (request.ErrandStatus == ErrandStatus.Assigned)
                {
                    var unavailable = await _settlement.ReportUnavailableAsync(request,
                        $"السعر في المتجر ({model.PurchaseCost:N0} ل.س) أعلى من السعر المعتمد ({request.ErrandItemPrice.Value:N0} ل.س). لم يتم الشراء.", driver.Id);
                    if (!unavailable.Success)
                        return unavailable.Conflict
                            ? Conflict(ApiErr.Create(unavailable.Error))
                            : BadRequest(ApiErr.Create(unavailable.Error));
                    return Conflict(ApiErr.Create("سعر المتجر أعلى من السعر الذي وافق عليه العميل. لم يتم الشراء؛ أُرسلت الحالة للإدارة لطلب موافقة جديدة."));
                }
                return Conflict(ApiErr.Create("المبلغ يتجاوز السعر المعتمد. لم يتم تعديل الطلب؛ حدّثه أو تواصل مع الإدارة."));
            }
            var file = model.ReceiptPhoto;
            if (file != null && file.Length > 0)
            {
                var ext = Path.GetExtension(file.FileName)?.ToLowerInvariant();
                if (!new[] { ".jpg", ".jpeg", ".png", ".webp" }.Contains(ext) || file.Length > 10 * 1024 * 1024)
                    return BadRequest(ApiErr.Create("صورة الفاتورة يجب أن تكون jpg أو png أو webp وألا تتجاوز 10 ميجابايت."));
            }
            if (string.IsNullOrWhiteSpace(model.ReceiptReference) && (file == null || file.Length == 0))
                return BadRequest(ApiErr.Create("أدخل رقم الإيصال أو أرفق صورة الفاتورة."));
            string photoToken = null;
            if (file != null && file.Length > 0)
            {
                try { photoToken = await _env.SaveFile(file, FileHelper.FileTypesAllowed.Image); }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Failed to save errand receipt for {ErrandId}.", id);
                    await TrackFailure(request, driver.Id, "تعذر رفع صورة فاتورة الشراء إلى الخادم.");
                    return StatusCode(500, ApiErr.Create("تعذر حفظ صورة الفاتورة. حاول مجدداً."));
                }
                if (string.IsNullOrWhiteSpace(photoToken))
                {
                    await TrackFailure(request, driver.Id, "تعذر رفع صورة فاتورة الشراء إلى الخادم.");
                    return BadRequest(ApiErr.Create("تعذر حفظ صورة الفاتورة."));
                }
            }
            var previousPhotoToken = request.ErrandReceiptPhotoToken;
            ErrandSettlementResult result;
            try
            {
                result = await _settlement.RecordPurchaseAsync(request, model.PurchaseCost,
                    model.ReceiptReference, photoToken, driver.Id, "Delivery");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to settle errand purchase {ErrandId}.", id);
                await DeleteReceiptPhotoIfUnreferenced(photoToken, id);
                return StatusCode(StatusCodes.Status500InternalServerError,
                    ApiErr.Create("تعذر تسجيل الشراء الآن. حدّث الطلب للتحقق قبل إعادة المحاولة."));
            }
            if (!result.Success)
            {
                await DeleteReceiptPhotoIfUnreferenced(photoToken, id);
                return result.Conflict ? Conflict(ApiErr.Create(result.Error)) : BadRequest(ApiErr.Create(result.Error));
            }
            if (!string.IsNullOrWhiteSpace(photoToken) &&
                !string.IsNullOrWhiteSpace(previousPhotoToken) &&
                previousPhotoToken != photoToken)
            {
                DeleteReceiptPhoto(previousPhotoToken, id);
            }
            return Ok(ToDto(request));
        }

        [HttpPost("{id:int}/deliver")]
        public async Task<ActionResult<DriverErrandDto>> Deliver(int id, [FromBody] CompleteErrandDeliveryDto model)
        {
            var driver = await _users.GetUserAsync(User);
            if (driver == null) return Unauthorized();
            var request = await _db.SupportMessages.FirstOrDefaultAsync(x =>
                x.Id == id && x.ErrandDriverUserId == driver.Id && x.ErrandStatus != null);
            if (request == null) return NotFound();
            if (_settlement == null) return StatusCode(503, ApiErr.Create("خدمة تأكيد التسليم غير متاحة حالياً."));
            if (model == null) return BadRequest(ApiErr.Create("بيانات تأكيد التسليم مطلوبة."));
            if (request.ErrandStatus == ErrandStatus.Delivered) return Ok(ToDto(request));
            if (request.ErrandDeliveryCodeFailedAttempts >= 5)
                return StatusCode(StatusCodes.Status423Locked, ApiErr.Create("أوقف تأكيد التسليم بعد محاولات كثيرة. تواصل مع الإدارة لإكمال الطلب."));
            if (!string.IsNullOrEmpty(request.ErrandDeliveryCode) && model.DeliveryCode != request.ErrandDeliveryCode)
            {
                request.ErrandDeliveryCodeFailedAttempts++;
                await TrackFailure(request, driver.Id, "رمز تسليم غير صحيح.");
                return request.ErrandDeliveryCodeFailedAttempts >= 5
                    ? StatusCode(StatusCodes.Status423Locked, ApiErr.Create("أوقف تأكيد التسليم بعد محاولات كثيرة. تواصل مع الإدارة لإكمال الطلب."))
                    : BadRequest(ApiErr.Create("رمز التسليم غير صحيح. تحقق من العميل وحاول مجدداً."));
            }
            var result = await _settlement.RecordDeliveryAsync(request, model.CollectedAmount,
                model.DeliveryCode, model.CustomerReceived, model.CashCollected, driver.Id, "Delivery");
            if (!result.Success)
            {
                // Cash validation and settlement retries are not wrong PIN attempts.
                await TrackFailure(request, driver.Id, result.Error ?? "فشل تأكيد التسليم.");
                return result.Conflict ? Conflict(ApiErr.Create(result.Error)) : BadRequest(ApiErr.Create(result.Error));
            }
            return Ok(ToDto(request));
        }

        [HttpPost("{id:int}/unavailable")]
        public async Task<ActionResult<DriverErrandDto>> ReportUnavailable(int id, [FromBody] ReportErrandUnavailableDto model)
        {
            var driver = await _users.GetUserAsync(User);
            if (driver == null) return Unauthorized();
            var request = await _db.SupportMessages.FirstOrDefaultAsync(x =>
                x.Id == id && x.ErrandDriverUserId == driver.Id && x.ErrandStatus != null);
            if (request == null) return NotFound();
            if (_settlement == null) return StatusCode(503, ApiErr.Create("خدمة طلبات الشراء غير متاحة حالياً."));
            var result = await _settlement.ReportUnavailableAsync(request, model?.Reason, driver.Id);
            if (!result.Success)
                return result.Conflict ? Conflict(ApiErr.Create(result.Error)) : BadRequest(ApiErr.Create(result.Error));
            return Ok(ToDto(request));
        }

        [HttpGet]
        public async Task<ActionResult<DriverErrandDto[]>> List()
        {
            var driver = await _users.GetUserAsync(User);
            if (driver == null) return Unauthorized();
            var query = _db.SupportMessages.AsNoTracking()
                .Where(x => x.ErrandDriverUserId == driver.Id && x.ErrandStatus != null);
            // Recent history must never displace an older, still-active assignment.
            var active = await query.Where(x => x.ErrandStatus == ErrandStatus.Assigned ||
                    x.ErrandStatus == ErrandStatus.Purchased || x.ErrandStatus == ErrandStatus.PurchasePending ||
                    x.ErrandStatus == ErrandStatus.DeliveryPending || x.ErrandStatus == ErrandStatus.ReturnPending ||
                    x.ErrandStatus == ErrandStatus.Unavailable)
                .OrderByDescending(x => x.CreatedDate).ToArrayAsync();
            var history = await query.Where(x => x.ErrandStatus == ErrandStatus.Delivered ||
                    x.ErrandStatus == ErrandStatus.Cancelled || x.ErrandStatus == ErrandStatus.Returned)
                .OrderByDescending(x => x.CreatedDate).Take(20).ToArrayAsync();
            return Ok(active.Concat(history).Select(ToDto).ToArray());
        }

        [HttpGet("{id:int}")]
        public async Task<ActionResult<DriverErrandDto>> Get(int id)
        {
            var driver = await _users.GetUserAsync(User);
            if (driver == null) return Unauthorized();
            var request = await _db.SupportMessages.AsNoTracking()
                .FirstOrDefaultAsync(x => x.Id == id && x.ErrandDriverUserId == driver.Id && x.ErrandStatus != null);
            return request == null ? NotFound() : Ok(ToDto(request));
        }

        [HttpPost("{id:int}/receipt")]
        [RequestSizeLimit(11 * 1024 * 1024)]
        public async Task<ActionResult<DriverErrandDto>> SubmitReceipt(int id, [FromForm] SubmitErrandReceiptDto model)
        {
            var driver = await _users.GetUserAsync(User);
            if (driver == null) return Unauthorized();
            var request = await _db.SupportMessages.FirstOrDefaultAsync(x =>
                x.Id == id && x.ErrandDriverUserId == driver.Id && x.ErrandStatus != null);
            if (request == null) return NotFound();
            if (request.ErrandStatus != ErrandStatus.Assigned &&
                request.ErrandStatus != ErrandStatus.PurchasePending &&
                request.ErrandStatus != ErrandStatus.Purchased)
                return Conflict(ApiErr.Create("يمكن إرسال أو تعديل فاتورة الشراء قبل تسليم الطلب فقط."));

            if (model == null)
                return BadRequest(ApiErr.Create("بيانات الفاتورة مطلوبة."));
            if (model.PurchaseCost <= 0)
                return BadRequest(ApiErr.Create("يرجى إدخال مبلغ صحيح مدفوع للمحل."));
            if (request.ErrandItemPrice.HasValue && model.PurchaseCost > request.ErrandItemPrice.Value)
                return BadRequest(ApiErr.Create($"المبلغ المدفوع ({model.PurchaseCost:N0} ل.س) يتجاوز السعر المعتمد للغرض ({request.ErrandItemPrice.Value:N0} ل.س). يرجى مراجعة الإدارة."));
            if (decimal.Round(model.PurchaseCost, 2) != model.PurchaseCost)
                return BadRequest(ApiErr.Create("مبلغ الشراء غير صالح."));
            if ((model.ReceiptReference?.Trim().Length ?? 0) > 200)
                return BadRequest(ApiErr.Create("رقم الإيصال طويل جداً (الحد الأقصى 200 حرف)."));

            var file = model.ReceiptPhoto;
            if (file != null && file.Length > 0)
            {
                var ext = Path.GetExtension(file.FileName)?.ToLowerInvariant();
                var allowedExts = new[] { ".jpg", ".jpeg", ".png", ".webp" };
                if (string.IsNullOrEmpty(ext) || !allowedExts.Contains(ext))
                    return BadRequest(ApiErr.Create("صيغة صورة الفاتورة غير مدعومة. استخدم jpg أو png أو webp."));
                if (file.Length > 10 * 1024 * 1024)
                    return BadRequest(ApiErr.Create("حجم صورة الفاتورة يتجاوز 10 ميجابايت."));
            }

            if (string.IsNullOrWhiteSpace(model.ReceiptReference) && (file == null || file.Length == 0))
                return BadRequest(ApiErr.Create("أدخل رقم الإيصال أو أرفق صورة الفاتورة."));

            string newPhotoToken = null;
            var previousPhotoToken = request.ErrandReceiptPhotoToken;
            if (file != null && file.Length > 0)
            {
                try
                {
                    newPhotoToken = await _env.SaveFile(file, FileHelper.FileTypesAllowed.Image);
                    if (string.IsNullOrWhiteSpace(newPhotoToken))
                        return BadRequest(ApiErr.Create("تعذر حفظ صورة الفاتورة. استخدم صورة بصيغة jpg أو png أو webp."));
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Failed to store receipt photo for errand {ErrandId}.", id);
                    await TrackFailure(request, driver.Id, "تعذر رفع صورة فاتورة الشراء من إصدار المندوب القديم.");
                    return StatusCode(StatusCodes.Status500InternalServerError,
                        ApiErr.Create("تعذر حفظ صورة الفاتورة على الخادم. حاول مجدداً أو أرسل رقم الإيصال للدعم."));
                }
                request.ErrandReceiptPhotoToken = newPhotoToken;
            }
            if (request.ErrandStatus == ErrandStatus.Assigned || request.ErrandPurchaseCost == null || request.ErrandPurchaseCost == 0)
                request.ErrandPurchaseCost = model.PurchaseCost;
            if (!string.IsNullOrWhiteSpace(model.ReceiptReference))
                request.ErrandReceiptReference = model.ReceiptReference.Trim();

            try { await _db.SaveChangesAsync(); }
            catch (DbUpdateConcurrencyException)
            {
                DeleteReceiptPhoto(newPhotoToken, id);
                return Conflict(ApiErr.Create("تم تحديث الطلب من الإدارة. حدّث القائمة لمعرفة حالته الحالية."));
            }
            catch (DbUpdateException ex)
            {
                DeleteReceiptPhoto(newPhotoToken, id);
                _logger.LogError(ex, "Failed to save receipt details for errand {ErrandId}.", id);
                return StatusCode(StatusCodes.Status500InternalServerError,
                    ApiErr.Create("تعذر تسجيل الفاتورة في النظام. حدّث القائمة، وإذا بقي الطلب بانتظار الشراء فأعد المحاولة أو تواصل مع الإدارة."));
            }
            catch (Exception ex)
            {
                DeleteReceiptPhoto(newPhotoToken, id);
                _logger.LogError(ex, "Unexpected failure while saving receipt for errand {ErrandId}.", id);
                return StatusCode(StatusCodes.Status500InternalServerError,
                    ApiErr.Create("حدث خطأ أثناء تسجيل الفاتورة. حدّث القائمة قبل إعادة المحاولة."));
            }

            if (!string.IsNullOrWhiteSpace(newPhotoToken) &&
                !string.IsNullOrWhiteSpace(previousPhotoToken) &&
                previousPhotoToken != newPhotoToken)
                DeleteReceiptPhoto(previousPhotoToken, id);

            return Ok(ToDto(request));
        }

        private void DeleteReceiptPhoto(string token, int requestId)
        {
            if (string.IsNullOrWhiteSpace(token) || Path.GetFileName(token) != token) return;
            try
            {
                var path = _env.GetPhysicalPath(token);
                if (System.IO.File.Exists(path)) System.IO.File.Delete(path);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Could not clean up receipt photo for errand {ErrandId}.", requestId);
            }
        }

        private async Task DeleteReceiptPhotoIfUnreferenced(string token, int requestId)
        {
            if (string.IsNullOrWhiteSpace(token)) return;
            var persistedToken = await _db.SupportMessages.AsNoTracking()
                .Where(x => x.Id == requestId)
                .Select(x => x.ErrandReceiptPhotoToken)
                .FirstOrDefaultAsync();
            if (!string.Equals(persistedToken, token, StringComparison.Ordinal))
                DeleteReceiptPhoto(token, requestId);
        }

        private async Task TrackFailure(SupportMessage request, Guid actorId, string reason)
        {
            _db.ErrandStatusEvents.Add(new ErrandStatusEvent
            {
                SupportMessageId = request.Id,
                FromStatus = request.ErrandStatus.HasValue ? (int)request.ErrandStatus.Value : (int?)null,
                ToStatus = request.ErrandStatus.HasValue ? (int)request.ErrandStatus.Value : 0,
                ActorUserId = actorId,
                ActorRole = "Delivery",
                Note = "EXCEPTION: " + (reason ?? "فشل إجراء المندوب.").Substring(0, Math.Min((reason ?? "فشل إجراء المندوب.").Length, 480)),
                CreatedDate = DateTime.UtcNow
            });
            await _db.SaveChangesAsync();
        }

        private static DriverErrandDto ToDto(SupportMessage x) => new()
        {
            Id = x.Id, Message = x.Message, CustomerPhone = x.SenderPhone,
            Status = x.ErrandStatus.Value, ItemPrice = x.ErrandItemPrice.GetValueOrDefault(),
            DeliveryFee = x.ErrandDeliveryFee.GetValueOrDefault(),
            DriverEarning = x.ErrandDriverEarning ?? x.ErrandDeliveryFee.GetValueOrDefault(),
            TotalCashToCollect = x.ErrandItemPrice.GetValueOrDefault() + x.ErrandDeliveryFee.GetValueOrDefault(),
            PurchaseCost = x.ErrandPurchaseCost,
            ReceiptReference = x.ErrandReceiptReference,
            ReceiptPhotoToken = x.ErrandReceiptPhotoToken,
            UnavailableReason = x.ErrandUnavailableReason,
            CreatedDate = x.CreatedDate
        };
    }

    public class DriverErrandDto
    {
        public int Id { get; set; }
        public string Message { get; set; }
        public string CustomerPhone { get; set; }
        public ErrandStatus Status { get; set; }
        public decimal ItemPrice { get; set; }
        public decimal DeliveryFee { get; set; }
        public decimal DriverEarning { get; set; }
        public decimal TotalCashToCollect { get; set; }
        public decimal? PurchaseCost { get; set; }
        public string ReceiptReference { get; set; }
        public string ReceiptPhotoToken { get; set; }
        public string UnavailableReason { get; set; }
        public DateTime CreatedDate { get; set; }
    }

    public class SubmitErrandReceiptDto
    {
        [ModelBinder(BinderType = typeof(InvariantMoneyFormBinder))]
        public decimal PurchaseCost { get; set; }
        public string ReceiptReference { get; set; }
        public IFormFile ReceiptPhoto { get; set; }
    }

    public class CompleteErrandDeliveryDto
    {
        public decimal CollectedAmount { get; set; }
        public string DeliveryCode { get; set; }
        public bool CustomerReceived { get; set; }
        public bool CashCollected { get; set; }
    }

    public class ReportErrandUnavailableDto { public string Reason { get; set; } }
}
