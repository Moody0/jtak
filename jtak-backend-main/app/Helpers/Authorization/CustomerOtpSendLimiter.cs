using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using App.Shared.Data.App;
using App.Shared.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace App.Helpers.Authorization
{
    public sealed class CustomerOtpSendLimiter
    {
        private readonly AppDbContext _db;
        private readonly IHttpContextAccessor _context;
        private readonly IConfiguration _configuration;
        private readonly ILogger<CustomerOtpSendLimiter> _logger;

        public CustomerOtpSendLimiter(IAppUnitOfWork unitOfWork, IHttpContextAccessor context,
            IConfiguration configuration, ILogger<CustomerOtpSendLimiter> logger)
        {
            _db = unitOfWork.Context;
            _context = context;
            _configuration = configuration;
            _logger = logger;
        }

        // Must run inside the caller's short transaction. Successful reservations
        // are committed before sending: failures/timeouts still count against caps.
        public async Task ReserveAsync(string phone, DateTime now)
        {
            var minute = new DateTime(now.Year, now.Month, now.Day, now.Hour, now.Minute, 0, DateTimeKind.Utc);
            var hour = new DateTime(now.Year, now.Month, now.Day, now.Hour, 0, 0, DateTimeKind.Utc);
            var day = now.Date;
            var phoneKey = Hash(Encoding.UTF8.GetBytes(phone));
            var ip = _context.HttpContext?.Connection.RemoteIpAddress;
            if (ip?.IsIPv4MappedToIPv6 == true) ip = ip.MapToIPv4();
            var ipBytes = ip?.GetAddressBytes() ?? Encoding.UTF8.GetBytes("unknown");
            // IPv6 clients can change their host address; limit the whole /64.
            if (ipBytes.Length == 16) Array.Clear(ipBytes, 8, 8);
            var ipKey = Hash(ipBytes);
            var buckets = new List<(string Key, DateTime Start, int Limit)>
            {
                ("all:day", day, Limit("GlobalPerDay", 100)),
                ("ip:" + ipKey + ":minute", minute, Limit("IpPerMinute", 10)),
                ("ip:" + ipKey + ":hour", hour, Limit("IpPerHour", 30)),
                ("ip:" + ipKey + ":day", day, Limit("IpPerDay", 100)),
                ("phone:" + phoneKey + ":hour", hour, Limit("PhonePerHour", 3)),
                ("phone:" + phoneKey + ":day", day, Limit("PhonePerDay", 5))
            };
            // Consistent lock order prevents competing instances taking buckets
            // in opposite orders. These counters survive application restarts.
            buckets.Sort((a, b) => string.CompareOrdinal(a.Key, b.Key));
            foreach (var bucket in buckets)
            {
                await _db.Database.ExecuteSqlInterpolatedAsync($@"
                    INSERT INTO `CustomerOtpSendCounters` (`Bucket`, `WindowStart`, `SendCount`)
                    VALUES ({bucket.Key}, {bucket.Start}, 0)
                    ON DUPLICATE KEY UPDATE `Bucket` = `Bucket`;");
                var reserved = await _db.CustomerOtpSendCounters.Where(x => x.Bucket == bucket.Key &&
                    x.WindowStart == bucket.Start && x.SendCount < bucket.Limit)
                    .ExecuteUpdateAsync(s => s.SetProperty(x => x.SendCount, x => x.SendCount + 1));
                if (reserved == 1) continue;
                if (bucket.Key == "all:day")
                {
                    _logger.LogWarning("Customer OTP daily send ceiling reached ({Limit}); paid sends blocked", bucket.Limit);
                    throw new CustomerOtpException("خدمة رمز التحقق غير متاحة مؤقتاً. يرجى المحاولة لاحقاً أو التواصل مع الدعم.", 429);
                }
                throw new CustomerOtpException("تم طلب رموز تحقق كثيرة. يرجى الانتظار والمحاولة لاحقاً.", 429);
            }
        }

        private int Limit(string name, int fallback) =>
            int.TryParse(_configuration["Authentication:Wevlix:Limits:" + name], out var limit) && limit > 0
                ? limit : fallback;
        private static string Hash(byte[] bytes) => Convert.ToHexString(SHA256.HashData(bytes));
    }
}
