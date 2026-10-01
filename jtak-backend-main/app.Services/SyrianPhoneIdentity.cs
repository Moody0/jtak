using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using App.Shared.Entities;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace App.Shared.Services
{
    /// <summary>
    /// One identity for every spelling of a Syrian mobile number. Never
    /// silently pick one account when historical duplicate records exist.
    /// </summary>
    public static class SyrianPhoneIdentity
    {
        public static bool TryNormalize(string input, out string canonical)
        {
            canonical = null;
            if (string.IsNullOrWhiteSpace(input)) return false;

            var chars = new List<char>(input.Length);
            var trimmed = input.Trim();
            if (trimmed.Count(ch => ch == '+') > 1 ||
                (trimmed.Contains('+') && trimmed[0] != '+')) return false;
            foreach (var ch in trimmed)
            {
                if (ch >= '0' && ch <= '9') chars.Add(ch);
                else if (ch >= '٠' && ch <= '٩') chars.Add((char)('0' + ch - '٠'));
                else if (ch >= '۰' && ch <= '۹') chars.Add((char)('0' + ch - '۰'));
                else if (ch == '+' || ch == ' ' || ch == '-' || ch == '(' || ch == ')') { }
                else return false;
            }

            var digits = new string(chars.ToArray());
            if (digits.StartsWith("00963", StringComparison.Ordinal)) digits = digits.Substring(5);
            else if (digits.StartsWith("963", StringComparison.Ordinal)) digits = digits.Substring(3);
            else if (digits.StartsWith("0", StringComparison.Ordinal)) digits = digits.Substring(1);

            // Do not truncate extra digits or accept another country's number.
            if (digits.Length != 9 || digits[0] != '9' || digits.Any(c => c < '0' || c > '9'))
                return false;
            canonical = "+963" + digits;
            return true;
        }

        public static async Task<PhoneAccountMatch> FindAsync(UserManager<AppUser> users, string input)
        {
            if (!TryNormalize(input, out var canonical)) return new PhoneAccountMatch(null, false);
            var national = canonical.Substring(4);
            var variants = new[] { canonical, canonical.Substring(1), "00" + canonical.Substring(1),
                "0" + national, national };
            var candidates = await users.Users
                .Where(x => (x.PhoneNumber != null &&
                        (variants.Contains(x.PhoneNumber) || x.PhoneNumber.EndsWith(national))) ||
                     (x.UserName != null &&
                        (variants.Contains(x.UserName) || x.UserName.EndsWith(national))))
                .ToListAsync();
            var matches = candidates.Where(x => IsSamePhone(x.PhoneNumber, canonical) ||
                                                 IsSamePhone(x.UserName, canonical))
                .GroupBy(x => x.Id).Select(x => x.First()).ToArray();
            return new PhoneAccountMatch(matches.Length == 1 ? matches[0] : null, matches.Length > 1);
        }

        private static bool IsSamePhone(string candidate, string canonical) =>
            TryNormalize(candidate, out var normalized) && normalized == canonical;
    }

    public sealed class PhoneAccountMatch
    {
        public PhoneAccountMatch(AppUser user, bool ambiguous)
        {
            User = user;
            Ambiguous = ambiguous;
        }

        public AppUser User { get; }
        public bool Ambiguous { get; }
    }
}
