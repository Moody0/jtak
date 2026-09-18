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
        private readonly IAdminAuditService _auditService;

        public SettlementRequestsController(ISettlementRequestService service, INotificationService notifications, IAdminAuditService auditService = null)
        {
            _service = service;
            _notifications = notifications;
            _auditService = auditService;
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
                try
                {
                    if (_notifications != null && result.RequestedByUserId != Guid.Empty)
                    {
                        var isMerchant = result.PartyType == SettlementPartyType.Merchant;
                        await _notifications.SendSettlementApproved(
                            new[] { result.RequestedByUserId },
                            result.RequestNumber,
                            result.Amount,
                            isMerchant);
                    }
                }
                catch
                {
                    // Notification failure must not fail or corrupt successful database approval
                }

                if (_auditService != null)
                {
                    await _auditService.LogAsync(new AdminAuditLogEntry
                    {
                        Module = "Settlements",
                        Action = "Approve",
                        EntityType = "SettlementRequest",
                        EntityId = result.RequestNumber ?? id.ToString(),
                        Description = $"الموافقة على طلب تسوية {result.RequestedByName} بمبلغ {result.Amount:N0} ل.س",
                        Result = "Success",
                        AfterState = result
                    });
                }

                return Ok(result);
            }
            catch (InvalidOperationException ex)
            {
                if (_auditService != null)
                {
                    await _auditService.LogAsync(new AdminAuditLogEntry
                    {
                        Module = "Settlements",
                        Action = "Approve",
                        EntityType = "SettlementRequest",
                        EntityId = id.ToString(),
                        Description = $"فشل الموافقة على طلب تسوية #{id}",
                        Result = "Failed",
                        FailureReason = ex.Message
                    });
                }
                return BadRequest(ApiErr.Create(ex.Message));
            }
        }

        [HttpPost("{id}/Reject")]
        public async Task<ActionResult<SettlementRequestDto>> Reject(Guid id, [FromBody] ReviewSettlementRequestDto request = null)
        {
            try
            {
                var result = await _service.RejectAsync(id, User.GetUserId() ?? Guid.Empty, request?.Reason);
                try
                {
                    if (_notifications != null && result.RequestedByUserId != Guid.Empty)
                    {
                        await _notifications.SendSettlementRejected(
                            new[] { result.RequestedByUserId },
                            result.RequestNumber,
                            result.Amount,
                            result.RejectionReason);
                    }
                }
                catch
                {
                    // Notification failure must not fail or corrupt successful database rejection
                }

                if (_auditService != null)
                {
                    await _auditService.LogAsync(new AdminAuditLogEntry
                    {
                        Module = "Settlements",
                        Action = "Reject",
                        EntityType = "SettlementRequest",
                        EntityId = result.RequestNumber ?? id.ToString(),
                        Description = $"رفض طلب تسوية {result.RequestedByName} بمبلغ {result.Amount:N0} ل.س - السبب: {request?.Reason}",
                        Result = "Success",
                        AfterState = result
                    });
                }

                return Ok(result);
            }
            catch (InvalidOperationException ex)
            {
                if (_auditService != null)
                {
                    await _auditService.LogAsync(new AdminAuditLogEntry
                    {
                        Module = "Settlements",
                        Action = "Reject",
                        EntityType = "SettlementRequest",
                        EntityId = id.ToString(),
                        Description = $"فشل رفض طلب تسوية #{id}",
                        Result = "Failed",
                        FailureReason = ex.Message
                    });
                }
                return BadRequest(ApiErr.Create(ex.Message));
            }
        }

        [HttpPost("{id}/Complete")]
        public async Task<ActionResult<SettlementRequestDto>> Complete(Guid id, [FromBody] ReviewSettlementRequestDto request = null)
        {
            try
            {
                var result = await _service.CompleteMerchantPayoutAsync(id, User.GetUserId() ?? Guid.Empty, request?.Notes);
                try
                {
                    if (_notifications != null && result.RequestedByUserId != Guid.Empty)
                    {
                        await _notifications.SendSettlementCompleted(
                            new[] { result.RequestedByUserId },
                            result.RequestNumber,
                            result.Amount);
                    }
                }
                catch
                {
                    // Notification failure must not fail or corrupt successful database completion
                }

                if (_auditService != null)
                {
                    await _auditService.LogAsync(new AdminAuditLogEntry
                    {
                        Module = "Settlements",
                        Action = "Pay",
                        EntityType = "SettlementRequest",
                        EntityId = result.RequestNumber ?? id.ToString(),
                        Description = $"إتمام صرف تسوية التاجر {result.RequestedByName} بمبلغ {result.Amount:N0} ل.س",
                        Result = "Success",
                        AfterState = result
                    });
                }

                return Ok(result);
            }
            catch (InvalidOperationException ex)
            {
                if (_auditService != null)
                {
                    await _auditService.LogAsync(new AdminAuditLogEntry
                    {
                        Module = "Settlements",
                        Action = "Pay",
                        EntityType = "SettlementRequest",
                        EntityId = id.ToString(),
                        Description = $"فشل صرف تسوية التاجر #{id}",
                        Result = "Failed",
                        FailureReason = ex.Message
                    });
                }
                return BadRequest(ApiErr.Create(ex.Message));
            }
        }
    }
}
