using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Hosting;
using System.Threading;
using App.Resources;
using App.Helpers;
using Solf.Services;
using App.Shared.Services.Helpers;
using App.Shared.Services.Extentions;
using App.Shared.Entities.Enums;
using App.Shared.Entities;

namespace App.Extensions
{
    public static class UserManagerExtensions
    {
        /*
        public static AppUser GetCachedUserAsync(this UserManager<AppUser> userManager, ClaimsPrincipal user)
        {
            throw new NotImplementedException();
            return new AppUser();
        }
        */
        public static async Task<List<AppRoleName>> GetRoleNamesAsync(this UserManager<AppUser> userManager, AppUser user)
        {
            var roles = await userManager.GetRolesAsync(user);
            var roleNames = new List<AppRoleName>();

            foreach (var role in roles)
            {
                if (Enum.TryParse(typeof(AppRoleName), role, out object r))
                {
                    roleNames.Add((AppRoleName)r);
                }
            }

            return roleNames;
        }


        public static async Task<AppUser> FindByPhoneNumberAsync(this UserManager<AppUser> userManager, string phoneNumber) =>
            await userManager.Users.FirstOrDefaultAsync(x => x.PhoneNumber == phoneNumber);

        public static async Task<List<AppUser>> GetUsersInOtherRoles(this UserManager<AppUser> userManager, params string[] roles)
        {
            var exceptUserIds = new List<Guid>();
            foreach (var r in roles)
            {
                exceptUserIds.AddRange((await userManager.GetUsersInRoleAsync(r)).Select(x => x.Id).ToList());
            }
            return userManager.Users.ToList().Where(x => !exceptUserIds.Contains(x.Id)).ToList();
        }


        public static async Task<AppUser> CreateOrLinkLogin(this UserManager<AppUser> _userManager,
            IWebHostEnvironment _env,
            string loginProvider,
            string providerKey,
            string email,
            string displayName,
            string deviceId,
            string pictureUrl = null)
        {
            var user = await _userManager.FindByLoginAsync(loginProvider, providerKey);

            // if user login already exist, return
            if (user != null) return await _userManager.UpdateUserOnLogin(_env, user, pictureUrl);

            user = await _userManager.FindByEmailAsync(email) ?? await _userManager.FindByNameAsync(email);

            if (user != null)
            {
                // Link exsisting user
                if (!user.IsActive) throw new Exception(_Authorization.UserAccountInactive);
                if (user.DeletionDate != null) throw new Exception(_Authorization.InvalidUsernamePassword);

                var r = await _userManager.AddLoginAsync(user, new UserLoginInfo(loginProvider, providerKey, displayName));
                if (!r.Succeeded) throw new Exception(_Authorization.CannotAddLoginToUserAccount);

                return await _userManager.UpdateUserOnLogin(_env, user, pictureUrl);
            }

            var fname = displayName.Split(" ").FirstOrDefault();
            var lname = displayName.Replace(displayName.Split(" ").FirstOrDefault(), "");

            // Add new user
            user = new AppUser
            {
                UserName = email,
                Email = email,
                EmailConfirmed = true,
                FirstName = fname,
                LastName = lname,
                FullName = displayName,
                IsActive = true,
                DeviceId = deviceId
            };
            var result = await _userManager.CreateAsync(user);
            if (!result.Succeeded) throw new Exception(_Authorization.CannotCreatUserAccount);

            // Set user role
            result = await _userManager.AddToRoleAsync(user, nameof(AppRoleName.Customer));
            if (!result.Succeeded) throw new Exception(_Authorization.CannotCreatUserRole);

            // Add external login to user
            result = await _userManager.AddLoginAsync(user, new UserLoginInfo(loginProvider, providerKey, displayName));
            if (!result.Succeeded) throw new Exception(_Authorization.CannotAddLoginToUserAccount);

            return await _userManager.UpdateUserOnLogin(_env, user, pictureUrl);
        }
        public static async Task SendPasswordResetEmail(this UserManager<AppUser> _userManager, IEmailService service, AppUser user)
        {
            var code = await _userManager.GeneratePasswordResetTokenAsync(user);
            //var callbackUrl = Url.Action("ResetPassword", "Account", new { user.Email, code, culture = Thread.CurrentThread.CurrentCulture.TwoLetterISOLanguageName }, "https");
            code = Uri.EscapeDataString(code);
            var callbackUrl = $"{AppDomainHelper.BaseUrl}/{Thread.CurrentThread.CurrentCulture.TwoLetterISOLanguageName}/Account/ResetPassword?Email={user.Email}&code={code}";
            await service.SendPasswordResetTokenAsync(user.FullName, user.Email, callbackUrl);
        }
        public static async Task SendEmailConfirmationEmail(this UserManager<AppUser> _userManager, IEmailService service, AppUser user)
        {
            var diff = DateTime.UtcNow - (user.LastConfirmEmail ?? DateTime.UtcNow.AddYears(-1));
            if (diff.TotalHours < 48)
                return;

            var code = await _userManager.GenerateEmailConfirmationTokenAsync(user);
            //var callbackUrl = Url.Action("ConfirmEmail", "Account", new { user.Email, code, culture = Thread.CurrentThread.CurrentCulture.TwoLetterISOLanguageName }, "https");
            code = Uri.EscapeDataString(code);
            var callbackUrl = $"{AppDomainHelper.BaseUrl}/{Thread.CurrentThread.CurrentCulture.TwoLetterISOLanguageName}/Account/ConfirmEmail?Email={user.Email}&code={code}";
            await service.SendEmailConfirmationAsync(user.FullName, user.Email, callbackUrl);
        }

        public static async Task SendEmailChangeConfirmationEmail(this UserManager<AppUser> _userManager, IEmailService service, AppUser user, string newEmail)
        {
            var code = await _userManager.GenerateChangeEmailTokenAsync(user, newEmail);
            //var callbackUrl = Url.Action("ChangeEmail", "Account", new { user.Email, code, culture = Thread.CurrentThread.CurrentCulture.TwoLetterISOLanguageName }, "https");
            code = Uri.EscapeDataString(code);
            var callbackUrl = $"{AppDomainHelper.BaseUrl}/{Thread.CurrentThread.CurrentCulture.TwoLetterISOLanguageName}/Account/ChangeEmail?Email={newEmail}&code={code}";
            await service.SendEmailConfirmationAsync(user.FullName, user.Email, callbackUrl);
        }

        private static async Task<AppUser> UpdateUserOnLogin(this UserManager<AppUser> _userManager, IWebHostEnvironment _env, AppUser user, string pictureUrl)
        {
            if (user.ProfilePhoto == null)
            {
                user.ProfilePhoto = pictureUrl != null ? await _env.SaveFileFromUrl(pictureUrl) : user.ProfilePhoto;
            }
            user.EmailConfirmed = true;
            user.LastLoginDate = DateTime.UtcNow;
            await _userManager.UpdateAsync(user);
            return user;
        }

        private static long RandomExcept(long min, long max, params long[] except)
        {
            var r = new Random();
            var random = LongRandom(min, max, r);
            while (except.Contains(random))
                random = (random + 1) % max;

            return random;
        }
        private static long LongRandom(long min, long max, Random rand)
        {
            byte[] buf = new byte[8];
            rand.NextBytes(buf);
            long longRand = BitConverter.ToInt64(buf, 0);

            return (Math.Abs(longRand % (max - min)) + min);
        }
    }
}
