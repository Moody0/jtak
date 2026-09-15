using App.ApiModels;
using App.Extensions;
using App.Shared.Entities.Enums;
using App.Shared.Services;
using App.Shared.Services.Extentions;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Modules.Accounting.Entities;
using Modules.Accounting.Services;
using OpenIddict.Validation.AspNetCore;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace App.ApiControllers.V1.Admin
{
    [Route("api/v{version:apiVersion}/Admin/[controller]")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.AdminPermission))]
    public class SettlementRequestsController : SolApiController
    {
        private readonly ISettlementRequestService _service;
        private readonly INotificationService _notifications;

        public SettlementRequestsController(ISettlementRequestService service, INotificationService notifications)
        {
            _service = service;
            _notifications = notifications;
        }

        [HttpGet]
        public async Task<ActionResult<List<SettlementRequestDto>>> GetAll(
            [FromQuery] SettlementRequestStatus? status = null,
            [FromQuery] SettlementPartyType? partyType = null) =>
            Ok(await _service.GetAllAsync(status, partyType));

        [HttpPost("{id}/Accept")]
        public async Task<ActionResult<SettlementRequestDto>> Accept(Guid id, [FromBody] ReviewSettlementRequestDto request = null)
        {
            try
            {
                var result = await _service.AcceptAsync(id, User.GetUserId() ?? Guid.Empty, request?.Notes);
                await _notifications.SendSettlementRequestStatus(new[] { result.RequestedByUserId }, result.RequestNumber, result.Amount, result.Status.ToString());
                return Ok(result);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ApiErr.Create(ex.Message));
            }
        }

        [HttpPost("{id}/Reject")]
        public async Task<ActionResult<SettlementRequestDto>> Reject(Guid id, [FromBody] ReviewSettlementRequestDto request = null)
        {
            try
            {
                var result = await _service.RejectAsync(id, User.GetUserId() ?? Guid.Empty, request?.Reason);
                await _notifications.SendSettlementRequestStatus(new[] { result.RequestedByUserId }, result.RequestNumber, result.Amount, result.Status.ToString(), result.RejectionReason);
                return Ok(result);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ApiErr.Create(ex.Message));
            }
        }

        [HttpPost("{id}/Complete")]
        public async Task<ActionResult<SettlementRequestDto>> Complete(Guid id, [FromBody] ReviewSettlementRequestDto request = null)
        {
            try
            {
                var result = await _service.CompleteMerchantPayoutAsync(id, User.GetUserId() ?? Guid.Empty, request?.Notes);
                await _notifications.SendSettlementRequestStatus(new[] { result.RequestedByUserId }, result.RequestNumber, result.Amount, result.Status.ToString());
                return Ok(result);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ApiErr.Create(ex.Message));
            }
        }
    }
}
