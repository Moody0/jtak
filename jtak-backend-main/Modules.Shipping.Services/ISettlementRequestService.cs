using Modules.Accounting.Entities;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace Modules.Accounting.Services
{
    public class MerchantSettlementSource
    {
        public int MerchantId { get; set; }
        public string MerchantTitle { get; set; }
    }

    public class SettlementBalanceDto
    {
        public decimal AvailableAmount { get; set; }
        public decimal PendingAmount { get; set; }
        public decimal GrossAmount { get; set; }
        public string Currency { get; set; } = "SYP";
        public bool HasPendingRequest { get; set; }
    }

    public interface ISettlementRequestService
    {
        Task<SettlementBalanceDto> GetCaptainBalanceAsync(Guid captainUserId, string currency = "SYP");
        Task<SettlementBalanceDto> GetMerchantBalanceAsync(IEnumerable<int> merchantIds, string currency = "SYP");
        Task<SettlementRequestDto> CreateCaptainRequestAsync(Guid userId, string name, string phone, CreateSettlementRequestDto request);
        Task<SettlementRequestDto> CreateMerchantRequestAsync(Guid userId, string name, string phone, IEnumerable<MerchantSettlementSource> merchants, CreateSettlementRequestDto request);
        Task<List<SettlementRequestDto>> GetMineAsync(Guid userId, SettlementPartyType partyType);
        Task<List<SettlementRequestDto>> GetAllAsync(SettlementRequestStatus? status = null, SettlementPartyType? partyType = null);
        Task<SettlementRequestDto> AcceptAsync(Guid requestId, Guid adminId, string notes = null);
        Task<SettlementRequestDto> RejectAsync(Guid requestId, Guid adminId, string reason = null);
        Task<SettlementRequestDto> CompleteMerchantPayoutAsync(Guid requestId, Guid adminId, string notes = null);
        Task<SettlementRequestDto> ConfirmMerchantReceiptAsync(Guid requestId, Guid merchantUserId, string notes = null);
    }
}
