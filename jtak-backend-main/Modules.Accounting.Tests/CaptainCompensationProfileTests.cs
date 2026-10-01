using System;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using App.Shared.Data.App;
using App.Shared.Entities;
using App.Shared.Entities.Enums;
using Xunit;

namespace Modules.Accounting.Tests
{
    public class CaptainCompensationProfileTests
    {
        private AppDbContext CreateInMemoryAppContext()
        {
            var options = new DbContextOptionsBuilder<AppDbContext>()
                .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
                .Options;
            return new AppDbContext(options, null);
        }

        [Fact]
        public void AppUser_DefaultsToSalariedEmployee_WithZeroRate()
        {
            var user = new AppUser();
            Assert.Equal(CaptainCompensationType.SalariedEmployee, user.CaptainCompensationType);
            Assert.Equal(0m, user.CaptainRate);
        }

        [Fact]
        public async Task AppUser_PerKilometer_PersistsCorrectlyInDbContext()
        {
            using var db = CreateInMemoryAppContext();
            var captain = new AppUser
            {
                Id = Guid.NewGuid(),
                FullName = "Captain Per Km",
                CaptainCompensationType = CaptainCompensationType.PerKilometer,
                CaptainRate = 25m
            };

            db.Users.Add(captain);
            await db.SaveChangesAsync();

            var fetched = await db.Users.FindAsync(captain.Id);
            Assert.NotNull(fetched);
            Assert.Equal(CaptainCompensationType.PerKilometer, fetched.CaptainCompensationType);
            Assert.Equal(25m, fetched.CaptainRate);
        }

        [Fact]
        public async Task AppUser_Percentage_PersistsCorrectlyInDbContext()
        {
            using var db = CreateInMemoryAppContext();
            var captain = new AppUser
            {
                Id = Guid.NewGuid(),
                FullName = "Captain Percentage",
                CaptainCompensationType = CaptainCompensationType.Percentage,
                CaptainRate = 60m
            };

            db.Users.Add(captain);
            await db.SaveChangesAsync();

            var fetched = await db.Users.FindAsync(captain.Id);
            Assert.NotNull(fetched);
            Assert.Equal(CaptainCompensationType.Percentage, fetched.CaptainCompensationType);
            Assert.Equal(60m, fetched.CaptainRate);
        }

        [Fact]
        public void UserDto_SupportsCaptainCompensationFields()
        {
            var dto = new UserDto
            {
                Id = Guid.NewGuid(),
                FullName = "Test Driver",
                Role = AppRoleName.Delivery,
                CaptainCompensationType = CaptainCompensationType.Percentage,
                CaptainRate = 60m
            };

            Assert.Equal(CaptainCompensationType.Percentage, dto.CaptainCompensationType);
            Assert.Equal(60m, dto.CaptainRate);
        }
    }
}
