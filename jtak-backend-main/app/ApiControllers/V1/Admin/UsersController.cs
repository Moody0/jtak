using AutoMapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using OpenIddict.Validation.AspNetCore;
using System;
using System.Linq;
using System.Threading.Tasks;
using App.Shared.Entities.Enums;
using Modules.Catalog.Services;
using Solf.Models;
using Microsoft.AspNetCore.Hosting;
using Microsoft.EntityFrameworkCore;
using App.Shared.Services;
using App.Shared.Entities;
using App.Shared.Data.App;
using Microsoft.AspNetCore.Identity;
using App.Shared.Services.Helpers;
using App.Extensions;
using URF.Core.Abstractions.Trackable;
using Solf.Identity;
using Solf.Extensions;

namespace App.ApiControllers.V1.Admin
{
    [Route("api/v{version:apiVersion}/Admin/[controller]")]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.AdminPermission))]
    public class UsersController : SolApiController
    {
        private readonly IUserService _service;
        private readonly ITagService _tagService;
        private readonly UserManager<AppUser> _userManager;
        private readonly RoleManager<SolRole> _roleManager;
        private readonly ITrackableRepository<AppUser> _userRepo;
        private readonly ITrackableRepository<SolUserRole> _userRoleRepo;
        private readonly IAppUnitOfWork _uow;
        private readonly ILogger _logger;
        private readonly IMapper _mapper;
        private readonly IWebHostEnvironment _env;

        public UsersController(UserManager<AppUser> userManager, IUserService service, ITagService tagService, IAppUnitOfWork uow, IMapper mapper, IWebHostEnvironment env, ILogger<UsersController> logger,
                                    RoleManager<SolRole> roleManager,
                                    ITrackableRepository<AppUser> userRepo,
                                    ITrackableRepository<SolUserRole> userRoleRepo)
        {
            _env = env;
            _service = service;
            _userManager = userManager;
            _tagService = tagService;
            _uow = uow;
            _uow = uow;
            _logger = logger;
            _mapper = mapper;
            _roleManager = roleManager;
            _userRepo = userRepo;
            _userRoleRepo = userRoleRepo;
        }

        /// <summary>
        /// Get a paged/filtered/ordered list of Users
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Route("DataTable")]
        public async Task<ActionResult<TableResponseModel<UserDto>>> DataTable([FromBody] MetronicTable request,
            [FromQuery] AppRoleName? role = null)
        {
            var r = role.HasValue ? await _roleManager.FindByNameAsync(role.ToString()) : null;
            var Users = _userRepo.Queryable() as DbSet<AppUser>;
            var UserRoles = _userRoleRepo.Queryable() as DbSet<SolUserRole>;
            var q = request?.Search?.Trim()?.ToLower();
            var doSearch = !string.IsNullOrWhiteSpace(q);

            if (role.HasValue)
            {
                var query = from userrole in UserRoles
                            join user in Users on userrole.UserId equals user.Id
                            where userrole.RoleId.Equals(r.Id) && user.DeletionDate == null
                            select user;

                return await query.ListMetronicTableQueryable(request,
                                item => new UserDto
                                {
                                    Id = item.Id,
                                    FirstName = item.FirstName,
                                    LastName = item.LastName,
                                    FullName = item.FullName,
                                    Gender = item.Gender,
                                    IsActive = item.IsActive,
                                    ProfilePhoto = item.ProfilePhoto,
                                    Birthday = item.Birthday,
                                    PhoneNumber = item.PhoneNumber,
                                    CountryPhoneCode = item.CountryPhoneCode,
                                    Email = item.Email,
                                    EmailConfirmed = true,
                                    Role = role.Value
                                });
            }
            var list = await _service.ListMetronicTableQueryable(request, item => new UserDto
            {
                Id = item.Id,
                FirstName = item.FirstName,
                LastName = item.LastName,
                FullName = item.FullName,
                Gender = item.Gender,
                IsActive = item.IsActive,
                ProfilePhoto = item.ProfilePhoto,
                Birthday = item.Birthday,
                PhoneNumber = item.PhoneNumber,
                CountryPhoneCode = item.CountryPhoneCode,
                Email = item.Email,
                EmailConfirmed = true
            }, x => x.Email != AppDomainHelper.AdminEmail && x.DeletionDate == null);

            foreach (var item in list.Items)
            {
                var user = await _userManager.Users.FirstOrDefaultAsync(x => x.Id == item.Id);
                item.Role = (await _userManager.GetRoleNamesAsync(user))?.FirstOrDefault() ?? AppRoleName.Customer;
            }
            return list;
        }

        /// <summary>
        /// Create a new User
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        public async Task<ActionResult<Guid>> Create(UserDto item)
        {
            var countryCode = !string.IsNullOrWhiteSpace(item.CountryPhoneCode) ? item.CountryPhoneCode.Trim() : "+963";
            if (!countryCode.StartsWith("+")) countryCode = "+" + countryCode;

            var rawPhone = item.PhoneNumber?.Trim() ?? "";
            if (rawPhone.StartsWith(countryCode))
            {
                rawPhone = rawPhone.Substring(countryCode.Length);
            }
            else if (rawPhone.StartsWith(countryCode.TrimStart('+')))
            {
                rawPhone = rawPhone.Substring(countryCode.TrimStart('+').Length);
            }
            rawPhone = rawPhone.TrimStart('0');

            var fullPhone = countryCode + rawPhone;
            var email = !string.IsNullOrWhiteSpace(item.Email) ? item.Email.Trim() : $"{rawPhone}@jtak.app";

            var entity = new AppUser
            {
                FirstName = item.FirstName?.Trim() ?? "",
                LastName = item.LastName?.Trim() ?? "",
                FullName = $"{item.FirstName} {item.LastName}".Trim(),
                Gender = item.Gender,
                IsActive = item.IsActive,
                ProfilePhoto = item.ProfilePhoto,
                Birthday = item.Birthday,
                PhoneNumber = fullPhone,
                CountryPhoneCode = countryCode,
                Email = email,
                UserName = fullPhone,
                EmailConfirmed = true
            };

            var password = !string.IsNullOrWhiteSpace(item.Password) ? item.Password.Trim() : "123456";
            var result = await _userManager.CreateAsync(entity, password);
            if (!result.Succeeded)
                return BadRequest(result);

            var role = item.Role.ToString();
            await _userManager.AddToRoleAsync(entity, role);
            _logger.LogInformation("Created New {0} with role {1}", entity.GetType().Name, role);
            return entity.Id;
        }

        /// <summary>
        /// Edit a User
        /// </summary>
        /// <returns></returns>
        [HttpPut]
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        [Route("{id}")]
        public async Task<ActionResult<Guid>> Edit(Guid id, UserDto item)
        {
            var entity = await _userManager.Users.FirstOrDefaultAsync(x => x.Id == id);
            if (entity == null) return NotFound();

            var countryCode = !string.IsNullOrWhiteSpace(item.CountryPhoneCode)
                ? item.CountryPhoneCode.Trim()
                : (!string.IsNullOrWhiteSpace(entity.CountryPhoneCode) ? entity.CountryPhoneCode : "+963");
            if (!countryCode.StartsWith("+")) countryCode = "+" + countryCode;

            var rawPhone = item.PhoneNumber?.Trim() ?? "";
            if (rawPhone.StartsWith(countryCode))
            {
                rawPhone = rawPhone.Substring(countryCode.Length);
            }
            else if (rawPhone.StartsWith(countryCode.TrimStart('+')))
            {
                rawPhone = rawPhone.Substring(countryCode.TrimStart('+').Length);
            }
            rawPhone = rawPhone.TrimStart('0');

            var fullPhone = countryCode + rawPhone;

            entity.FirstName = item.FirstName?.Trim() ?? entity.FirstName;
            entity.LastName = item.LastName?.Trim() ?? entity.LastName;
            entity.FullName = $"{item.FirstName} {item.LastName}".Trim();
            entity.Gender = item.Gender;
            entity.IsActive = item.IsActive;
            entity.ProfilePhoto = item.ProfilePhoto;
            entity.Birthday = item.Birthday;
            entity.PhoneNumber = fullPhone;
            entity.CountryPhoneCode = countryCode;
            if (!string.IsNullOrWhiteSpace(item.Email))
            {
                entity.Email = item.Email.Trim();
            }
            entity.UserName = fullPhone;
            entity.EmailConfirmed = true;
            entity.DefaultLat = item.DefaultLat;
            entity.DefaultLng = item.DefaultLng;

            var res = await _userManager.UpdateAsync(entity);
            if (!res.Succeeded)
            {
                return BadRequest(res);
            }

            if (!string.IsNullOrWhiteSpace(item.Password))
            {
                var token = await _userManager.GeneratePasswordResetTokenAsync(entity);
                var passResult = await _userManager.ResetPasswordAsync(entity, token, item.Password.Trim());
                if (!passResult.Succeeded)
                {
                    return BadRequest(passResult);
                }
            }

            var currentRoles = await _userManager.GetRolesAsync(entity);

            res = await _userManager.RemoveFromRolesAsync(entity, currentRoles);

            if (!res.Succeeded)
            {
                return BadRequest(res);
            }
            var role = item.Role.ToString();
            res = await _userManager.AddToRoleAsync(entity, role);
            if (!res.Succeeded)
            {
                return BadRequest(res);
            }

            return entity.Id;
        }

        /// <summary>
        /// Enable User
        /// </summary>
        /// <returns></returns>
        [HttpPut]
        [Route("{id}/Enable")]
        public async Task<ActionResult<bool>> Enable(Guid id)
        {
            var user = await _userManager.Users.FirstOrDefaultAsync(x => x.Id == id);
            user.IsActive = true;
            await _userManager.UpdateAsync(user);
            return true;
        }

        /// <summary>
        /// Disable User
        /// </summary>
        /// <returns></returns>
        [HttpPut]
        [Route("{id}/Disable")]
        public async Task<ActionResult<bool>> Disable(Guid id)
        {
            var user = await _userManager.Users.FirstOrDefaultAsync(x => x.Id == id);
            user.IsActive = false;
            await _userManager.UpdateAsync(user);
            return true;
        }

        /// <summary>
        /// Delete User
        /// </summary>
        /// <returns></returns>
        [HttpDelete]
        [Route("{id}")]
        public async Task<ActionResult<bool>> Delete(Guid id)
        {
            var user = await _userManager.Users.FirstOrDefaultAsync(x => x.Id == id);
            if (user == null) return NotFound();
            if (user.Email == AppDomainHelper.AdminEmail)
            {
                return BadRequest("Cannot delete root admin user");
            }
            user.IsActive = false;
            user.DeletionDate = DateTime.UtcNow;
            await _userManager.UpdateAsync(user);
            return true;
        }



        /// <summary>
        /// Get Merchant Users
        /// </summary>
        /// <returns></returns>
        [HttpGet]
        [Route("Merchants")]
        public async Task<ActionResult<UserDto[]>> GetMerchants()
        {
            return (await _service.ListFromRoles(AppRoleName.Merchant.ToString())).Select(x => new UserDto
            {
                Id = x.Id,
                FirstName = x.FirstName,
                LastName = x.LastName,
                FullName = x.FullName,
                Gender = x.Gender,
                IsActive = x.IsActive,
                ProfilePhoto = x.ProfilePhoto,
                Birthday = x.Birthday,
                PhoneNumber = x.PhoneNumber,
                CountryPhoneCode = x.CountryPhoneCode,
                Email = x.Email,
                EmailConfirmed = x.EmailConfirmed
            }).ToArray();
        }

        /// <summary>
        /// Get Delivery Users
        /// </summary>
        /// <returns></returns>
        [HttpGet]
        [Route("Deliveries")]
        public async Task<ActionResult<UserDto[]>> GetDeliveries()
        {
            return (await _service.ListFromRoles(AppRoleName.Delivery.ToString())).Select(x => new UserDto
            {
                Id = x.Id,
                FirstName = x.FirstName,
                LastName = x.LastName,
                FullName = x.FullName,
                Gender = x.Gender,
                IsActive = x.IsActive,
                ProfilePhoto = x.ProfilePhoto,
                Birthday = x.Birthday,
                PhoneNumber = x.PhoneNumber,
                CountryPhoneCode = x.CountryPhoneCode,
                Email = x.Email,
                EmailConfirmed = x.EmailConfirmed
            }).ToArray();
        }



        [HttpGet]
        [Route("Roles")]
        public ActionResult<TagVal[]> Roles() =>
            TagVal.Create<AppRoleName>();
    }

    public struct TagVal
    {
        public static TagVal[] Create<TEnum>() where TEnum : struct, Enum =>
            Enum.GetValues<TEnum>().Where(x => Convert.ToInt64(x) > 0).Select(x => Create(Convert.ToInt64(x), x.ToLocalizedName(), x.ToLocalizedDescription())).ToArray();

        public static TagVal Create(long key, string val, string desc = null) => new() { Key = key, Value = val, Description = desc };

        public long Key { get; set; }
        public string Value { get; set; }
        public string Description { get; set; }
    }
}
