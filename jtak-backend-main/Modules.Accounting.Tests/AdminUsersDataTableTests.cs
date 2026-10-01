using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using App.Shared.Data.App;
using App.Shared.Entities;
using App.Shared.Entities.Enums;
using Solf.Identity;
using Solf.Models;
using Xunit;

namespace Modules.Accounting.Tests
{
    public class AdminUsersDataTableTests
    {
        private AppDbContext CreateInMemoryAppContext()
        {
            var options = new DbContextOptionsBuilder<AppDbContext>()
                .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
                .Options;
            return new AppDbContext(options, null);
        }

        [Fact]
        public async Task QueryExecution_SingleDbContext_IncludesCustomersMerchantsAndDeliveryCouriersButExcludesAdmins()
        {
            using var appContext = CreateInMemoryAppContext();

            // Roles
            var customerRole = new SolRole { Id = Guid.NewGuid(), Name = AppRoleName.Customer.ToString(), NormalizedName = AppRoleName.Customer.ToString().ToUpper() };
            var deliveryRole = new SolRole { Id = Guid.NewGuid(), Name = AppRoleName.Delivery.ToString(), NormalizedName = AppRoleName.Delivery.ToString().ToUpper() };
            var adminRole = new SolRole { Id = Guid.NewGuid(), Name = AppRoleName.Admin.ToString(), NormalizedName = AppRoleName.Admin.ToString().ToUpper() };
            var merchantRole = new SolRole { Id = Guid.NewGuid(), Name = AppRoleName.Merchant.ToString(), NormalizedName = AppRoleName.Merchant.ToString().ToUpper() };
            appContext.Roles.AddRange(customerRole, deliveryRole, adminRole, merchantRole);

            // Users
            var customer = new AppUser { Id = Guid.NewGuid(), FirstName = "Ahmad", LastName = "Ali", FullName = "Ahmad Ali", PhoneNumber = "0944111222", IsActive = true, CreatedDate = DateTime.UtcNow };
            var courier = new AppUser { Id = Guid.NewGuid(), FirstName = "Sami", LastName = "Delivery", FullName = "Sami Delivery", PhoneNumber = "0955333444", IsActive = true, CreatedDate = DateTime.UtcNow };
            var admin = new AppUser { Id = Guid.NewGuid(), FirstName = "Root", LastName = "Admin", FullName = "Root Admin", PhoneNumber = "0999000111", IsActive = true, CreatedDate = DateTime.UtcNow };
            var merchant = new AppUser { Id = Guid.NewGuid(), FirstName = "Shop", LastName = "Owner", FullName = "Shop Owner", PhoneNumber = "0988777666", IsActive = true, CreatedDate = DateTime.UtcNow };
            appContext.Users.AddRange(customer, courier, admin, merchant);

            // UserRoles
            appContext.UserRoles.AddRange(
                new SolUserRole { UserId = customer.Id, RoleId = customerRole.Id },
                new SolUserRole { UserId = courier.Id, RoleId = deliveryRole.Id },
                new SolUserRole { UserId = admin.Id, RoleId = adminRole.Id },
                new SolUserRole { UserId = merchant.Id, RoleId = merchantRole.Id }
            );
            await appContext.SaveChangesAsync();

            var uow = new AppUnitOfWork(appContext);
            var db = uow.Context;
            Assert.NotNull(db);

            // Execute the exact role scope used in UsersController.DataTable
            var visibleRoles = new[] { AppRoleName.Customer, AppRoleName.Merchant, AppRoleName.Delivery };
            var visibleRoleNames = visibleRoles.Select(r => r.ToString()).ToList();
            var visibleRoleIds = await db.Roles.AsNoTracking()
                .Where(x => visibleRoleNames.Contains(x.Name))
                .Select(x => x.Id)
                .ToListAsync();

            var query = (from user in db.Users.AsNoTracking()
                         join userRole in db.UserRoles.AsNoTracking() on user.Id equals userRole.UserId
                         where visibleRoleIds.Contains(userRole.RoleId) && user.DeletionDate == null
                         select user).Distinct();

            var totalRecords = await query.CountAsync();
            var pagedUsers = await query.OrderByDescending(x => x.CreatedDate).Take(10).ToListAsync();

            Assert.Equal(3, totalRecords);
            Assert.Equal(3, pagedUsers.Count);
            Assert.Contains(pagedUsers, u => u.Id == customer.Id);
            Assert.Contains(pagedUsers, u => u.Id == courier.Id);
            Assert.Contains(pagedUsers, u => u.Id == merchant.Id);
            Assert.DoesNotContain(pagedUsers, u => u.Id == admin.Id);
        }

        [Fact]
        public async Task QueryExecution_SingleDbContext_WithRoleFilter_FiltersCorrectly()
        {
            using var appContext = CreateInMemoryAppContext();

            var customerRole = new SolRole { Id = Guid.NewGuid(), Name = AppRoleName.Customer.ToString(), NormalizedName = AppRoleName.Customer.ToString().ToUpper() };
            var deliveryRole = new SolRole { Id = Guid.NewGuid(), Name = AppRoleName.Delivery.ToString(), NormalizedName = AppRoleName.Delivery.ToString().ToUpper() };
            var merchantRole = new SolRole { Id = Guid.NewGuid(), Name = AppRoleName.Merchant.ToString(), NormalizedName = AppRoleName.Merchant.ToString().ToUpper() };
            appContext.Roles.AddRange(customerRole, deliveryRole, merchantRole);

            var customer = new AppUser { Id = Guid.NewGuid(), FirstName = "Ahmad", LastName = "Ali", FullName = "Ahmad Ali", PhoneNumber = "0944111222", IsActive = true, CreatedDate = DateTime.UtcNow };
            var courier = new AppUser { Id = Guid.NewGuid(), FirstName = "Sami", LastName = "Delivery", FullName = "Sami Delivery", PhoneNumber = "0955333444", IsActive = true, CreatedDate = DateTime.UtcNow };
            var merchant = new AppUser { Id = Guid.NewGuid(), FirstName = "Shop", LastName = "Owner", FullName = "Shop Owner", PhoneNumber = "0988777666", IsActive = true, CreatedDate = DateTime.UtcNow };
            appContext.Users.AddRange(customer, courier, merchant);

            appContext.UserRoles.AddRange(
                new SolUserRole { UserId = customer.Id, RoleId = customerRole.Id },
                new SolUserRole { UserId = courier.Id, RoleId = deliveryRole.Id },
                new SolUserRole { UserId = merchant.Id, RoleId = merchantRole.Id }
            );
            await appContext.SaveChangesAsync();

            var uow = new AppUnitOfWork(appContext);
            var db = uow.Context;

            var role = AppRoleName.Merchant;
            var targetRole = await db.Roles.AsNoTracking().FirstOrDefaultAsync(x => x.Name == role.ToString());
            Assert.NotNull(targetRole);

            var query = (from user in db.Users.AsNoTracking()
                         join userRole in db.UserRoles.AsNoTracking() on user.Id equals userRole.UserId
                         where userRole.RoleId == targetRole.Id && user.DeletionDate == null
                         select user).Distinct();

            var totalRecords = await query.CountAsync();
            var paged = await query.ToListAsync();

            Assert.Equal(1, totalRecords);
            Assert.Equal(merchant.Id, paged.Single().Id);
        }

        [Fact]
        public async Task QueryExecution_SingleDbContext_WithSearch_FiltersByNameOrPhone()
        {
            using var appContext = CreateInMemoryAppContext();

            var customerRole = new SolRole { Id = Guid.NewGuid(), Name = AppRoleName.Customer.ToString(), NormalizedName = AppRoleName.Customer.ToString().ToUpper() };
            appContext.Roles.Add(customerRole);

            var user1 = new AppUser { Id = Guid.NewGuid(), FirstName = "Khaled", LastName = "Homs", FullName = "Khaled Homs", PhoneNumber = "0933999888", IsActive = true, CreatedDate = DateTime.UtcNow };
            var user2 = new AppUser { Id = Guid.NewGuid(), FirstName = "Omar", LastName = "Sham", FullName = "Omar Sham", PhoneNumber = "0944111222", IsActive = true, CreatedDate = DateTime.UtcNow };
            appContext.Users.AddRange(user1, user2);

            appContext.UserRoles.AddRange(
                new SolUserRole { UserId = user1.Id, RoleId = customerRole.Id },
                new SolUserRole { UserId = user2.Id, RoleId = customerRole.Id }
            );
            await appContext.SaveChangesAsync();

            var uow = new AppUnitOfWork(appContext);
            var db = uow.Context;

            var term = "999888";
            var query = (from user in db.Users.AsNoTracking()
                         join userRole in db.UserRoles.AsNoTracking() on user.Id equals userRole.UserId
                         where userRole.RoleId == customerRole.Id && user.DeletionDate == null
                         select user).Distinct();

            query = query.Where(u =>
                (u.PhoneNumber != null && u.PhoneNumber.Contains(term)) ||
                (u.FullName != null && u.FullName.ToLower().Contains(term)) ||
                (u.FirstName != null && u.FirstName.ToLower().Contains(term)) ||
                (u.LastName != null && u.LastName.ToLower().Contains(term)) ||
                (u.Email != null && u.Email.ToLower().Contains(term))
            );

            var totalRecords = await query.CountAsync();
            var results = await query.ToListAsync();

            Assert.Equal(1, totalRecords);
            Assert.Equal(user1.Id, results.Single().Id);
        }
    }
}
