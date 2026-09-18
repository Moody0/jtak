using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using App.Shared.Data.App;
using App.Shared.Entities;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Solf.Models;

namespace App.Shared.Services
{
    public class AdminAuditService : IAdminAuditService
    {
        private readonly AppDbContext _context;
        private readonly IHttpContextAccessor _httpContextAccessor;

        public AdminAuditService(AppDbContext context, IHttpContextAccessor httpContextAccessor)
        {
            _context = context;
            _httpContextAccessor = httpContextAccessor;
        }

        public async Task LogAsync(AdminAuditLogEntry entry)
        {
            if (entry == null) return;

            var httpContext = _httpContextAccessor?.HttpContext;
            var user = httpContext?.User;

            Guid? adminUserId = entry.AdminUserId;
            string adminName = entry.AdminName;
            string adminEmail = entry.AdminEmail;
            string ipAddress = entry.IpAddress;
            string userAgent = entry.UserAgent;
            string correlationId = entry.CorrelationId;

            if (!adminUserId.HasValue && user != null)
            {
                var subClaim = user.FindFirst(ClaimTypes.NameIdentifier)?.Value ??
                               user.FindFirst("sub")?.Value;
                if (Guid.TryParse(subClaim, out var parsedGuid))
                {
                    adminUserId = parsedGuid;
                }
            }

            if (string.IsNullOrWhiteSpace(adminName) && user != null)
            {
                adminName = user.FindFirst(ClaimTypes.Name)?.Value ??
                            user.FindFirst("name")?.Value ??
                            user.Identity?.Name;
            }

            if (string.IsNullOrWhiteSpace(adminEmail) && user != null)
            {
                adminEmail = user.FindFirst(ClaimTypes.Email)?.Value ??
                             user.FindFirst("email")?.Value;
            }

            if (string.IsNullOrWhiteSpace(ipAddress) && httpContext != null)
            {
                if (httpContext.Request.Headers.TryGetValue("X-Forwarded-For", out var forwardedFor) && !string.IsNullOrWhiteSpace(forwardedFor))
                {
                    ipAddress = forwardedFor.ToString().Split(',').FirstOrDefault()?.Trim();
                }
                else
                {
                    ipAddress = httpContext.Connection?.RemoteIpAddress?.ToString();
                }
            }

            if (string.IsNullOrWhiteSpace(userAgent) && httpContext != null)
            {
                userAgent = httpContext.Request.Headers["User-Agent"].ToString();
            }

            if (string.IsNullOrWhiteSpace(correlationId) && httpContext != null)
            {
                correlationId = httpContext.TraceIdentifier;
            }

            var beforeStateJson = entry.BeforeState != null ? AuditSanitizer.Sanitize(entry.BeforeState) : null;
            var afterStateJson = entry.AfterState != null ? AuditSanitizer.Sanitize(entry.AfterState) : null;

            var auditLog = new AdminAuditLog
            {
                Id = Guid.NewGuid(),
                CreatedDate = DateTime.UtcNow,
                AdminUserId = adminUserId,
                AdminName = adminName ?? "System Admin",
                AdminEmail = adminEmail,
                Module = entry.Module ?? "System",
                Action = entry.Action ?? "Execute",
                EntityType = entry.EntityType,
                EntityId = entry.EntityId,
                Description = AuditSanitizer.SanitizeText(entry.Description),
                Result = string.IsNullOrWhiteSpace(entry.Result) ? "Success" : entry.Result,
                FailureReason = AuditSanitizer.SanitizeText(entry.FailureReason),
                IpAddress = ipAddress,
                UserAgent = userAgent,
                CorrelationId = correlationId,
                BeforeStateJson = beforeStateJson,
                AfterStateJson = afterStateJson
            };

            _context.AdminAuditLogs.Add(auditLog);
            await _context.SaveChangesAsync();
        }

        public async Task<TableResponseModel<AdminAuditLogDto>> GetDataTableAsync(MetronicTable request, AdminAuditLogFilter filter = null)
        {
            var query = _context.AdminAuditLogs.AsNoTracking();

            if (filter != null)
            {
                if (!string.IsNullOrWhiteSpace(filter.Module))
                {
                    var mod = filter.Module.Trim();
                    query = query.Where(x => x.Module == mod);
                }

                if (!string.IsNullOrWhiteSpace(filter.Action))
                {
                    var act = filter.Action.Trim();
                    query = query.Where(x => x.Action == act);
                }

                if (!string.IsNullOrWhiteSpace(filter.Result))
                {
                    var res = filter.Result.Trim();
                    query = query.Where(x => x.Result == res);
                }

                if (filter.AdminUserId.HasValue && filter.AdminUserId.Value != Guid.Empty)
                {
                    query = query.Where(x => x.AdminUserId == filter.AdminUserId.Value);
                }

                if (filter.FromDate.HasValue)
                {
                    var fromUtc = filter.FromDate.Value.ToUniversalTime();
                    query = query.Where(x => x.CreatedDate >= fromUtc);
                }

                if (filter.ToDate.HasValue)
                {
                    var toUtc = filter.ToDate.Value.ToUniversalTime();
                    query = query.Where(x => x.CreatedDate <= toUtc);
                }
            }

            if (!string.IsNullOrWhiteSpace(request?.Search))
            {
                var search = request.Search.Trim().ToLower();
                query = query.Where(x =>
                    (x.Description != null && x.Description.ToLower().Contains(search)) ||
                    (x.AdminName != null && x.AdminName.ToLower().Contains(search)) ||
                    (x.AdminEmail != null && x.AdminEmail.ToLower().Contains(search)) ||
                    (x.EntityId != null && x.EntityId.ToLower().Contains(search)) ||
                    (x.Module != null && x.Module.ToLower().Contains(search)) ||
                    (x.Action != null && x.Action.ToLower().Contains(search)) ||
                    (x.CorrelationId != null && x.CorrelationId.ToLower().Contains(search)));
            }

            var totalRecords = await query.CountAsync();

            var sortField = request?.SortField?.Trim()?.ToLower();
            var sortAsc = string.Equals(request?.SortOrder, "ASC", StringComparison.OrdinalIgnoreCase);

            query = sortField switch
            {
                "createddate" => sortAsc ? query.OrderBy(x => x.CreatedDate) : query.OrderByDescending(x => x.CreatedDate),
                "adminname" => sortAsc ? query.OrderBy(x => x.AdminName) : query.OrderByDescending(x => x.AdminName),
                "module" => sortAsc ? query.OrderBy(x => x.Module) : query.OrderByDescending(x => x.Module),
                "action" => sortAsc ? query.OrderBy(x => x.Action) : query.OrderByDescending(x => x.Action),
                "result" => sortAsc ? query.OrderBy(x => x.Result) : query.OrderByDescending(x => x.Result),
                _ => query.OrderByDescending(x => x.CreatedDate)
            };

            var pageNumber = Math.Max(request?.PageNumber ?? 1, 1);
            var pageSize = Math.Max(request?.PageSize ?? 10, 1);

            var items = await query.Skip((pageNumber - 1) * pageSize)
                                   .Take(pageSize)
                                   .Select(x => new AdminAuditLogDto
                                   {
                                       Id = x.Id,
                                       CreatedDate = x.CreatedDate,
                                       AdminUserId = x.AdminUserId,
                                       AdminName = x.AdminName,
                                       AdminEmail = x.AdminEmail,
                                       Module = x.Module,
                                       Action = x.Action,
                                       EntityType = x.EntityType,
                                       EntityId = x.EntityId,
                                       Description = x.Description,
                                       Result = x.Result,
                                       FailureReason = x.FailureReason,
                                       IpAddress = x.IpAddress,
                                       UserAgent = x.UserAgent,
                                       CorrelationId = x.CorrelationId,
                                       BeforeStateJson = x.BeforeStateJson,
                                       AfterStateJson = x.AfterStateJson
                                   })
                                   .ToListAsync();

            return new TableResponseModel<AdminAuditLogDto>
            {
                Items = items.ToArray(),
                TotalRecords = totalRecords
            };
        }

        public async Task<AdminAuditLogSummaryDto> GetSummaryAsync()
        {
            var now = DateTime.UtcNow;
            var todayUtc = now.Date;
            var weekAgoUtc = now.AddDays(-7);

            var total = await _context.AdminAuditLogs.CountAsync();
            var today = await _context.AdminAuditLogs.CountAsync(x => x.CreatedDate >= todayUtc);
            var thisWeek = await _context.AdminAuditLogs.CountAsync(x => x.CreatedDate >= weekAgoUtc);
            var successCount = await _context.AdminAuditLogs.CountAsync(x => x.Result == "Success");
            var failureCount = await _context.AdminAuditLogs.CountAsync(x => x.Result != "Success");

            var topModuleGroup = await _context.AdminAuditLogs
                .Where(x => !string.IsNullOrEmpty(x.Module))
                .GroupBy(x => x.Module)
                .OrderByDescending(g => g.Count())
                .Select(g => g.Key)
                .FirstOrDefaultAsync();

            var topAdminGroup = await _context.AdminAuditLogs
                .Where(x => !string.IsNullOrEmpty(x.AdminName))
                .GroupBy(x => x.AdminName)
                .OrderByDescending(g => g.Count())
                .Select(g => g.Key)
                .FirstOrDefaultAsync();

            return new AdminAuditLogSummaryDto
            {
                TotalOperations = total,
                TodayOperations = today,
                ThisWeekOperations = thisWeek,
                SuccessCount = successCount,
                FailureCount = failureCount,
                TopModule = topModuleGroup ?? "Orders",
                TopAdmin = topAdminGroup ?? "Admin"
            };
        }

        public async Task<AdminAuditLogDto> GetByIdAsync(Guid id)
        {
            var item = await _context.AdminAuditLogs.AsNoTracking().FirstOrDefaultAsync(x => x.Id == id);
            if (item == null) return null;

            return new AdminAuditLogDto
            {
                Id = item.Id,
                CreatedDate = item.CreatedDate,
                AdminUserId = item.AdminUserId,
                AdminName = item.AdminName,
                AdminEmail = item.AdminEmail,
                Module = item.Module,
                Action = item.Action,
                EntityType = item.EntityType,
                EntityId = item.EntityId,
                Description = item.Description,
                Result = item.Result,
                FailureReason = item.FailureReason,
                IpAddress = item.IpAddress,
                UserAgent = item.UserAgent,
                CorrelationId = item.CorrelationId,
                BeforeStateJson = item.BeforeStateJson,
                AfterStateJson = item.AfterStateJson
            };
        }
    }
}
