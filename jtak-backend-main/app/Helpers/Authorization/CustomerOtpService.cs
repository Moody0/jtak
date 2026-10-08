using System;
using System.Data;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using App.Shared.Data.App;
using App.Shared.Entities;
using App.Shared.Entities.Enums;
using App.Shared.Services;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

namespace App.Helpers.Authorization
{
    public sealed class CustomerOtpService
    {
        public const string ReviewPhone = "+963900000000";
        public const string ReviewCode = "667788";
        public static readonly Guid ReviewUserId = new Guid("d7a91f82-cf52-4e4a-97a2-86fc6f7cd08e");
        private readonly AppDbContext _db;
        private readonly UserManager<AppUser> _users;
        private readonly WevlixOtpClient _wevlix;
        private readonly IConfiguration _configuration;
        private readonly CustomerOtpSendLimiter _sendLimiter;

        public CustomerOtpService(IAppUnitOfWork unitOfWork, UserManager<AppUser> users,
            WevlixOtpClient wevlix, IConfiguration configuration, CustomerOtpSendLimiter sendLimiter)
        {
            _db = unitOfWork.Context;
            _users = users;
            _wevlix = wevlix;
            _configuration = configuration;
            _sendLimiter = sendLimiter;
        }

        private bool ReviewEnabled => bool.TryParse(_configuration["Authentication:GooglePlayReview:Enabled"], out var enabled) && enabled;

        public async Task<AppUser> EnsureReviewAccountAsync(string phone)
        {
            if (phone != ReviewPhone || !ReviewEnabled) return null;
            var match = await SyrianPhoneIdentity.FindAsync(_users, phone);
            if (match.Ambiguous || (match.User != null && match.User.Id != ReviewUserId))
                throw new CustomerOtpException("رقم حساب المراجعة مرتبط بحساب آخر. يرجى التواصل مع الإدارة.", 409);
            var user = match.User;
            if (user == null)
            {
                user = new AppUser
                {
                    Id = ReviewUserId, UserName = ReviewPhone, PhoneNumber = ReviewPhone,
                    PhoneNumberConfirmed = true, IsActive = true,
                    FirstName = "Google Play", LastName = "Reviewer", FullName = "Google Play Reviewer"
                };
                var created = await _users.CreateAsync(user);
                if (!created.Succeeded)
                    throw new CustomerOtpException("تعذر إنشاء حساب المراجعة. يرجى التواصل مع الإدارة.", 503);
                var assigned = await _users.AddToRoleAsync(user, nameof(AppRoleName.Customer));
                if (!assigned.Succeeded)
                    throw new CustomerOtpException("تعذر إعداد حساب المراجعة. يرجى التواصل مع الإدارة.", 503);
            }
            else if ((await _users.GetRolesAsync(user)).Count == 0 &&
                     !(await _users.GetClaimsAsync(user)).Any(c => c.Type == DashboardAccessService.AccountMarker))
            {
                // Recover only our exact account if a previous role insert failed.
                if (!(await _users.AddToRoleAsync(user, nameof(AppRoleName.Customer))).Succeeded)
                    throw new CustomerOtpException("تعذر إعداد حساب المراجعة.", 503);
            }
            if (!await IsReviewAccountAsync(phone, user))
                throw new CustomerOtpException("حساب المراجعة غير متاح.", 403);
            return user;
        }

        private async Task<bool> IsReviewAccountAsync(string phone, AppUser user)
        {
            if (!ReviewEnabled || phone != ReviewPhone || user?.Id != ReviewUserId ||
                user.PhoneNumber != ReviewPhone || !user.IsActive || user.DeletionDate != null) return false;
            var roles = await _users.GetRolesAsync(user);
            var claims = await _users.GetClaimsAsync(user);
            return roles.Count == 1 && roles.Contains(nameof(AppRoleName.Customer)) &&
                !claims.Any(c => c.Type == DashboardAccessService.AccountMarker);
        }

        public async Task SendAsync(string phone, AppUser user, bool requiresProfile)
        {
            if (user != null && (!user.IsActive || user.DeletionDate != null))
                throw new CustomerOtpException("حسابك غير متاح. يرجى التواصل مع الدعم.", 403);
            var review = await IsReviewAccountAsync(phone, user);
            if (phone == ReviewPhone && !review)
                throw new CustomerOtpException("حساب المراجعة غير متاح.", 403);
            var id = Guid.NewGuid();
            var code = review ? ReviewCode : GenerateCode();
            var now = DateTime.UtcNow;
            // Reserve the cooldown, challenge and message budget before the
            // network request. An uncertain provider response cannot undo them.
            await using (var transaction = await _db.Database.BeginTransactionAsync(IsolationLevel.Serializable))
            {
                var old = await _db.CustomerOtpChallenges.FindAsync(phone);
                if (old != null && old.CreatedAt.AddSeconds(60) > now)
                    throw new CustomerOtpException("يرجى الانتظار دقيقة قبل طلب رمز جديد.", 429);
                if (!review) await _sendLimiter.ReserveAsync(phone, now);
                if (old != null) _db.CustomerOtpChallenges.Remove(old);
                if (old != null) await _db.SaveChangesAsync();
                _db.CustomerOtpChallenges.Add(new CustomerOtpChallenge
                {
                    PhoneNumber = phone, ChallengeId = id, UserId = user?.Id,
                    CodeHash = Hash(id, code),
                    CreatedAt = now, ExpiresAt = now.AddMinutes(5),
                    IsReview = review, RequiresProfileCompletion = requiresProfile
                });
                await _db.SaveChangesAsync();
                await transaction.CommitAsync();
            }
            if (!review)
            {
                var messageId = await _wevlix.SendAsync(phone, code, id);
                var saved = await _db.CustomerOtpChallenges.Where(x => x.PhoneNumber == phone && x.ChallengeId == id)
                    .ExecuteUpdateAsync(s => s.SetProperty(x => x.MessageId, messageId));
                if (saved != 1)
                    throw new CustomerOtpException("تعذر حفظ طلب رمز التحقق. يرجى طلب رمز جديد.", 503);
            }
        }

        public async Task<bool> VerifyAsync(string phone, string code, bool signupOnly = false)
        {
            var now = DateTime.UtcNow;
            var challenge = await _db.CustomerOtpChallenges.AsNoTracking().SingleOrDefaultAsync(x => x.PhoneNumber == phone);
            if (challenge == null || challenge.ConsumedAt != null || challenge.ExpiresAt <= now ||
                (!challenge.IsReview && string.IsNullOrWhiteSpace(challenge.MessageId)) ||
                challenge.FailedAttempts >= 5 || (signupOnly && !challenge.RequiresProfileCompletion)) return false;
            // Count attempts atomically, including concurrent verification requests.
            var reserved = await _db.CustomerOtpChallenges.Where(x => x.PhoneNumber == phone &&
                x.ChallengeId == challenge.ChallengeId && x.ConsumedAt == null && x.ExpiresAt > now && x.FailedAttempts < 5)
                .ExecuteUpdateAsync(s => s.SetProperty(x => x.FailedAttempts, x => x.FailedAttempts + 1));
            if (reserved != 1 || !Matches(challenge, code)) return false;
            if (challenge.IsReview)
            {
                var reviewer = await _users.FindByIdAsync(ReviewUserId.ToString());
                if (!await IsReviewAccountAsync(phone, reviewer)) return false;
            }
            else if (challenge.VerifiedAt == null &&
                     !await _wevlix.VerifyAsync(challenge.MessageId, code)) return false;
            return await _db.CustomerOtpChallenges.Where(x => x.PhoneNumber == phone &&
                x.ChallengeId == challenge.ChallengeId && x.ConsumedAt == null && x.ExpiresAt > DateTime.UtcNow)
                .ExecuteUpdateAsync(s => s.SetProperty(x => x.VerifiedAt, now)
                    .SetProperty(x => x.FailedAttempts, 0)) == 1;
        }

        public async Task<bool> ConsumeAsync(string phone, AppUser user, string code)
        {
            var challengeId = await _db.CustomerOtpChallenges.AsNoTracking()
                .Where(x => x.PhoneNumber == phone).Select(x => (Guid?)x.ChallengeId).SingleOrDefaultAsync();
            if (challengeId == null) return false;
            if (!await VerifyAsync(phone, code)) return false;
            var now = DateTime.UtcNow;
            return await _db.CustomerOtpChallenges.Where(x => x.PhoneNumber == phone &&
                x.ChallengeId == challengeId.Value &&
                (x.UserId == null || x.UserId == user.Id) && x.VerifiedAt != null &&
                x.ConsumedAt == null && x.ExpiresAt > now &&
                x.CodeHash != null)
                .ExecuteUpdateAsync(s => s.SetProperty(x => x.ConsumedAt, now)) == 1;
        }

        private static string GenerateCode()
        {
            string code;
            do { code = RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6"); }
            while (code == "123456" || code == ReviewCode);
            return code;
        }
        private static string Hash(Guid id, string code) => Convert.ToHexString(
            SHA256.HashData(Encoding.UTF8.GetBytes(id.ToString("N") + ":" + code)));
        private static bool Matches(CustomerOtpChallenge challenge, string code) =>
            code != null && code.Length == 6 && code.All(c => c >= '0' && c <= '9') &&
            CryptographicOperations.FixedTimeEquals(Encoding.ASCII.GetBytes(challenge.CodeHash),
                Encoding.ASCII.GetBytes(Hash(challenge.ChallengeId, code)));
    }
}
