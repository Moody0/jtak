using System;
using System.Threading.Tasks;
using App.Shared.Entities;
using App.Shared.Entities.Enums;
using App.Shared.Services.Helpers;
using Microsoft.AspNetCore.Identity;

namespace App.Setup
{
    public class SeedUsers
    {
        private readonly Random R = new();
        private readonly UserManager<AppUser> _userManager;
        public SeedUsers(UserManager<AppUser> userManager)
        {
            _userManager = userManager;
        }

        public async Task Seed()
        {
            await CreateUserInRole(AppDomainHelper.AdminEmail, AppRoleName.Admin);
            await CreateUserInRole(AppDomainHelper.UserEmail, AppRoleName.Customer);
            await CreateUserInRole(AppDomainHelper.MerchantEmail, AppRoleName.Merchant);
            await CreateUserInRole(AppDomainHelper.DeliveryEmail, AppRoleName.Delivery);
        }

        private async Task CreateUserInRole(string email, AppRoleName role, string password = "P@ssw0rd")
        {
            var user = await _userManager.FindByEmailAsync(email);
            if (user != null) return;

            user = new AppUser()
            {
                Email = email,
                EmailConfirmed = true,
                UserName = "+90555555555"+ ((int)role).ToString(),
                PhoneNumber = "+90555555555"+ ((int)role).ToString(),
                PhoneNumberConfirmed = true,
                FirstName = role.ToString(),
                LastName = "User",
                FullName = $"{role} User",
                Birthday = DateTime.Now.AddYears(R.Next(-50, -10)),
                NormalizedUserName = email,
                CreatedDate = DateTime.UtcNow
            };
            var result = await _userManager.CreateAsync(user, password);
            if (result.Succeeded)
            {
                result = await _userManager.AddToRoleAsync(user, role.ToString());
            }
        }
    }
}
