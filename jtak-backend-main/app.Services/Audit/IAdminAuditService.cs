using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Solf.Models;

namespace App.Shared.Services
{
    public class AdminAuditLogDto
    {
        public Guid Id { get; set; }
        public DateTime CreatedDate { get; set; }
        public Guid? AdminUserId { get; set; }
        public string AdminName { get; set; }
        public string AdminEmail { get; set; }
        public string Module { get; set; }
        public string Action { get; set; }
        public string EntityType { get; set; }
        public string EntityId { get; set; }
        public string Description { get; set; }
        public string Result { get; set; }
        public string FailureReason { get; set; }
        public string IpAddress { get; set; }
        public string UserAgent { get; set; }
        public string CorrelationId { get; set; }
        public string BeforeStateJson { get; set; }
        public string AfterStateJson { get; set; }
    }

    public class AdminAuditLogEntry
    {
        public Guid? AdminUserId { get; set; }
        public string AdminName { get; set; }
        public string AdminEmail { get; set; }
        public string Module { get; set; }
        public string Action { get; set; }
        public string EntityType { get; set; }
        public string EntityId { get; set; }
        public string Description { get; set; }
        public string Result { get; set; } = "Success";
        public string FailureReason { get; set; }
        public string IpAddress { get; set; }
        public string UserAgent { get; set; }
        public string CorrelationId { get; set; }
        public object BeforeState { get; set; }
        public object AfterState { get; set; }
    }

    public class AdminAuditLogSummaryDto
    {
        public int TotalOperations { get; set; }
        public int TodayOperations { get; set; }
        public int ThisWeekOperations { get; set; }
        public int SuccessCount { get; set; }
        public int FailureCount { get; set; }
        public string TopModule { get; set; }
        public string TopAdmin { get; set; }
    }

    public class AdminAuditLogFilter
    {
        public string Module { get; set; }
        public string Action { get; set; }
        public string Result { get; set; }
        public Guid? AdminUserId { get; set; }
        public DateTime? FromDate { get; set; }
        public DateTime? ToDate { get; set; }
    }

    public interface IAdminAuditService
    {
        Task LogAsync(AdminAuditLogEntry entry);
        Task<TableResponseModel<AdminAuditLogDto>> GetDataTableAsync(MetronicTable request, AdminAuditLogFilter filter = null);
        Task<AdminAuditLogSummaryDto> GetSummaryAsync();
        Task<AdminAuditLogDto> GetByIdAsync(Guid id);
    }
}
