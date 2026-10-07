using System;
using System.Linq;
using System.Threading.Tasks;
using App.ApiModels;
using App.Shared.Data.App;
using App.Shared.Entities;
using App.Shared.Entities.Domain;
using App.Shared.Entities.Enums;
using App.Shared.Services;
using AutoMapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using OpenIddict.Validation.AspNetCore;
using Solf.Models;
using Solf.Extensions;

namespace App.ApiControllers.V1.Admin
{
    [Route("api/v{version:apiVersion}/Admin/[controller]")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = App.Helpers.Authorization.DashboardAccessService.Policy)]
    [ApiVersion("1")]
    public class SupportMessagesController : SolApiController
    {
        private readonly ISupportMessageService _service;
        private readonly IAppUnitOfWork _uow;
        private readonly ILogger<SupportMessagesController> _logger;
        private readonly IMapper _mapper;

        public SupportMessagesController(
            ISupportMessageService service,
            IAppUnitOfWork uow,
            ILogger<SupportMessagesController> logger,
            IMapper mapper)
        {
            _service = service;
            _uow = uow;
            _logger = logger;
            _mapper = mapper;
        }

        /// <summary>
        /// Get paginated/filtered/ordered list of Support Messages for Admin
        /// </summary>
        [HttpPost]
        [Route("DataTable")]
        public async Task<ActionResult<TableResponseModel<SupportMessageDto>>> DataTable(
            [FromBody] MetronicTable request,
            [FromQuery] SupportMessageStatus? status = null)
        {
            if (request != null && request.PageNumber > 0)
            {
                request.PageNumber -= 1;
            }
            // Purchase requests have their own operations queue. They must not
            // be mixed into the support-ticket list or its status filters.
            var query = _service.Queryable().Where(x => x.ErrandStatus == null);

            if (status.HasValue)
            {
                query = query.Where(x => x.Status == status.Value);
            }

            var searchTerm = request?.Search?.Trim()?.ToLower();
            if (!string.IsNullOrWhiteSpace(searchTerm))
            {
                query = query.Where(x =>
                    (x.SenderName != null && x.SenderName.ToLower().Contains(searchTerm)) ||
                    (x.SenderPhone != null && x.SenderPhone.Contains(searchTerm)) ||
                    (x.Title != null && x.Title.ToLower().Contains(searchTerm)) ||
                    (x.Message != null && x.Message.ToLower().Contains(searchTerm)));
            }

            return await query
                .OrderByDescending(x => x.CreatedDate)
                .ListMetronicTableQueryable(request, x => new SupportMessageDto
                {
                    Id = x.Id,
                    UserId = x.UserId,
                    SenderName = x.SenderName,
                    SenderPhone = x.SenderPhone,
                    SenderEmail = x.SenderEmail,
                    Title = x.Title,
                    Message = x.Message,
                    Status = x.Status,
                    AdminNotes = x.AdminNotes,
                    CreatedDate = x.CreatedDate,
                    ResolvedDate = x.ResolvedDate,
                    ErrandStatus = x.ErrandStatus,
                    ErrandItemPrice = x.ErrandItemPrice,
                    ErrandDeliveryFee = x.ErrandDeliveryFee,
                    ErrandDriverEarning = x.ErrandDriverEarning ?? x.ErrandDeliveryFee,
                    ErrandQuoteExpiresAt = x.ErrandQuoteExpiresAt,
                    ErrandDriverUserId = x.ErrandDriverUserId,
                    ErrandPurchaseCost = x.ErrandPurchaseCost,
                    ErrandReceiptReference = x.ErrandReceiptReference,
                    ErrandReceiptPhotoToken = x.ErrandReceiptPhotoToken,
                    ErrandCashCollected = x.ErrandCashCollected,
                    ErrandRefundAmount = x.ErrandRefundAmount,
                    ErrandReturnReason = x.ErrandReturnReason
                });
        }

        /// <summary>
        /// Get overview statistics (Total, New, InProgress, Resolved)
        /// </summary>
        [HttpGet("stats")]
        public async Task<ActionResult<SupportMessageStatsDto>> GetStats()
        {
            return await _service.GetStatsAsync();
        }

        /// <summary>
        /// Get a single support message by ID and mark as read if it was new
        /// </summary>
        [HttpGet("{id}")]
        public async Task<ActionResult<SupportMessageDto>> Get(int id)
        {
            var msg = await _service.Queryable().FirstOrDefaultAsync(x => x.Id == id);
            if (msg == null) return NotFound();

            if (msg.ErrandStatus == null && msg.Status == SupportMessageStatus.New)
            {
                msg.Status = SupportMessageStatus.Read;
                await _uow.SaveChangesAsync();
            }

            return new SupportMessageDto
            {
                Id = msg.Id,
                UserId = msg.UserId,
                SenderName = msg.SenderName,
                SenderPhone = msg.SenderPhone,
                SenderEmail = msg.SenderEmail,
                Title = msg.Title,
                Message = msg.Message,
                Status = msg.Status,
                AdminNotes = msg.AdminNotes,
                CreatedDate = msg.CreatedDate,
                ResolvedDate = msg.ResolvedDate,
                ErrandStatus = msg.ErrandStatus,
                ErrandItemPrice = msg.ErrandItemPrice,
                ErrandDeliveryFee = msg.ErrandDeliveryFee,
                ErrandDriverEarning = msg.ErrandDriverEarning ?? msg.ErrandDeliveryFee,
                ErrandQuoteExpiresAt = msg.ErrandQuoteExpiresAt,
                ErrandDriverUserId = msg.ErrandDriverUserId,
                ErrandPurchaseCost = msg.ErrandPurchaseCost,
                ErrandReceiptReference = msg.ErrandReceiptReference,
                ErrandReceiptPhotoToken = msg.ErrandReceiptPhotoToken,
                ErrandCashCollected = msg.ErrandCashCollected,
                ErrandRefundAmount = msg.ErrandRefundAmount,
                ErrandReturnReason = msg.ErrandReturnReason,
                ErrandUnavailableReason = msg.ErrandUnavailableReason,
                ErrandDeliveryCodeFailedAttempts = msg.ErrandDeliveryCodeFailedAttempts,
                ErrandLatestException = await _uow.Context.ErrandStatusEvents.AsNoTracking()
                    .Where(x => x.SupportMessageId == msg.Id &&
                        x.Note != null && x.Note.StartsWith("EXCEPTION:"))
                    .OrderByDescending(x => x.CreatedDate)
                    .Select(x => x.Note)
                    .FirstOrDefaultAsync()
            };
        }

        /// <summary>
        /// Update support message status (New, Read/InProgress, Resolved) and optional admin resolution notes
        /// </summary>
        [HttpPut("{id}/status")]
        public async Task<ActionResult<bool>> UpdateStatus(int id, [FromBody] UpdateSupportMessageStatusDto model)
        {
            if (model == null || !Enum.IsDefined(typeof(SupportMessageStatus), model.Status))
                return BadRequest(ApiErr.Create("حالة رسالة الدعم غير صالحة."));
            if (await _service.Queryable().AnyAsync(x => x.Id == id && x.ErrandStatus != null))
                return BadRequest(ApiErr.Create("طلبات الشراء تُدار من خلال مراحل عرض السعر والتنفيذ المخصصة لها."));
            var success = await _service.UpdateStatusAsync(id, model.Status, model.AdminNotes);
            if (!success) return NotFound();
            return true;
        }

        /// <summary>
        /// Delete a support message
        /// </summary>
        [HttpDelete("{id}")]
        public async Task<ActionResult<bool>> Delete(int id)
        {
            var msg = await _service.Queryable().FirstOrDefaultAsync(x => x.Id == id);
            if (msg == null) return NotFound();
            if (msg.ErrandStatus != null)
                return BadRequest(ApiErr.Create("لا يمكن حذف طلب شراء له سجل مالي أو عرض سعر."));

            await _service.DeleteAsync(id);
            await _uow.SaveChangesAsync();
            return true;
        }
    }
}
