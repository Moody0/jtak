using System;
using System.Collections.Generic;
using System.Linq;
using Microsoft.Extensions.Configuration;

namespace App.Shared.Services
{
    public interface IOrderFeatureFlagService
    {
        bool IsCanonicalMoneyEngineEnabled(int? merchantId = null);
        bool IsStrictMerchantRadiusEnabled(int? merchantId = null);
        bool IsAtomicDriverClaimEnabled(Guid? driverId = null);
        bool IsStrictProofOfDeliveryEnabled(Guid? driverId = null);
        bool IsPeriodicAccountingRetryEnabled();
        bool IsContinuousInvariantAuditEnabled();
        int GetAuditIntervalMinutes();
    }

    public class OrderFeatureFlagService : IOrderFeatureFlagService
    {
        private readonly IConfiguration _configuration;

        public OrderFeatureFlagService(IConfiguration configuration)
        {
            _configuration = configuration ?? throw new ArgumentNullException(nameof(configuration));
        }

        public bool IsCanonicalMoneyEngineEnabled(int? merchantId = null)
        {
            if (IsCanaryMerchant(merchantId)) return true;
            return ReadBool("Features:CanonicalMoneyEngine", true);
        }

        public bool IsStrictMerchantRadiusEnabled(int? merchantId = null)
        {
            if (IsCanaryMerchant(merchantId)) return true;
            return ReadBool("Features:StrictMerchantRadius", true);
        }

        public bool IsAtomicDriverClaimEnabled(Guid? driverId = null)
        {
            if (IsCanaryDriver(driverId)) return true;
            return ReadBool("Features:AtomicDriverClaim", true);
        }

        public bool IsStrictProofOfDeliveryEnabled(Guid? driverId = null)
        {
            if (IsCanaryDriver(driverId)) return true;
            return ReadBool("Features:StrictProofOfDelivery", true);
        }

        public bool IsPeriodicAccountingRetryEnabled()
        {
            return ReadBool("Features:PeriodicAccountingRetry", true);
        }

        public bool IsContinuousInvariantAuditEnabled()
        {
            return ReadBool("Features:ContinuousInvariantAudit", true);
        }

        public int GetAuditIntervalMinutes()
        {
            var raw = _configuration["Features:AuditIntervalMinutes"];
            return int.TryParse(raw, out var minutes) && minutes > 0 ? minutes : 60;
        }

        private bool ReadBool(string key, bool defaultValue)
        {
            var raw = _configuration[key];
            if (string.IsNullOrWhiteSpace(raw)) return defaultValue;
            return bool.TryParse(raw, out var val) ? val : defaultValue;
        }

        private bool IsCanaryMerchant(int? merchantId)
        {
            if (!merchantId.HasValue) return false;
            var children = _configuration.GetSection("Features:CanaryWhitelistMerchantIds").GetChildren();
            return children.Any(c => int.TryParse(c.Value, out var id) && id == merchantId.Value);
        }

        private bool IsCanaryDriver(Guid? driverId)
        {
            if (!driverId.HasValue) return false;
            var idStr = driverId.Value.ToString();
            var children = _configuration.GetSection("Features:CanaryWhitelistDriverIds").GetChildren();
            return children.Any(c => string.Equals(c.Value, idStr, StringComparison.OrdinalIgnoreCase));
        }
    }
}
