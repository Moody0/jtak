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
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.AdminPermission))]
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
            var query = _service.Queryable();

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
                    ResolvedDate = x.ResolvedDate
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

            if (msg.Status == SupportMessageStatus.New)
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
                ResolvedDate = msg.ResolvedDate
            };
        }

        /// <summary>
        /// Update support message status (New, Read/InProgress, Resolved) and optional admin resolution notes
        /// </summary>
        [HttpPut("{id}/status")]
        public async Task<ActionResult<bool>> UpdateStatus(int id, [FromBody] UpdateSupportMessageStatusDto model)
        {
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

            await _service.DeleteAsync(id);
            await _uow.SaveChangesAsync();
            return true;
        }
    }
}
