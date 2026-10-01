using AutoMapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using OpenIddict.Validation.AspNetCore;
using System;
using System.Linq;
using System.Threading.Tasks;
using System.ComponentModel.DataAnnotations;
using App.Shared.Entities.Enums;
using App.ApiModels;
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
        private readonly IAdminAuditService _auditService;
        private readonly INotificationService _notificationService;

        public UsersController(UserManager<AppUser> userManager, IUserService service, ITagService tagService, IAppUnitOfWork uow, IMapper mapper, IWebHostEnvironment env, ILogger<UsersController> logger,
                                    RoleManager<SolRole> roleManager,
                                    ITrackableRepository<AppUser> userRepo,
                                    ITrackableRepository<SolUserRole> userRoleRepo,
                                    IAdminAuditService auditService = null,
                                    INotificationService notificationService = null)
        {
            _env = env;
            _service = service;
            _userManager = userManager;
            _tagService = tagService;
            _uow = uow;
            _logger = logger;
            _mapper = mapper;
            _roleManager = roleManager;
            _userRepo = userRepo;
            _userRoleRepo = userRoleRepo;
            _auditService = auditService;
            _notificationService = notificationService;
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
            // Keep the global account directory inclusive of app-facing account roles.
            // Admin accounts remain excluded from this operational list.
            var visibleRoles = new[] { AppRoleName.Customer, AppRoleName.Merchant, AppRoleName.Delivery };
            if (role.HasValue && !visibleRoles.Contains(role.Value))
            {
                return new TableResponseModel<UserDto>
                {
                    Items = Array.Empty<UserDto>(),
                    TotalRecords = 0
                };
            }

            var db = _uow.Context;
            IQueryable<AppUser> query;

            if (role.HasValue)
            {
                var roleNameStr = role.Value.ToString();
                var targetRole = await db.Roles.AsNoTracking().FirstOrDefaultAsync(x => x.Name == roleNameStr);
                if (targetRole == null)
                {
                    return BadRequest($"Unknown user role: {role.Value}");
                }

                query = (from user in db.Users.AsNoTracking()
                         join userRole in db.UserRoles.AsNoTracking() on user.Id equals userRole.UserId
                         where userRole.RoleId == targetRole.Id && user.DeletionDate == null
                         select user).Distinct();
            }
            else
            {
                var visibleRoleNames = visibleRoles.Select(r => r.ToString()).ToList();
                var visibleRoleIds = await db.Roles.AsNoTracking()
                    .Where(x => visibleRoleNames.Contains(x.Name))
                    .Select(x => x.Id)
                    .ToListAsync();

                query = (from user in db.Users.AsNoTracking()
                         join userRole in db.UserRoles.AsNoTracking() on user.Id equals userRole.UserId
                         where visibleRoleIds.Contains(userRole.RoleId) && user.DeletionDate == null
                         select user).Distinct();
            }

            // Server-side search filter
            if (!string.IsNullOrWhiteSpace(request?.Search))
            {
                var term = request.Search.Trim().ToLower();
                query = query.Where(u =>
                    (u.PhoneNumber != null && u.PhoneNumber.Contains(term)) ||
                    (u.FullName != null && u.FullName.ToLower().Contains(term)) ||
                    (u.FirstName != null && u.FirstName.ToLower().Contains(term)) ||
                    (u.LastName != null && u.LastName.ToLower().Contains(term)) ||
                    (u.Email != null && u.Email.ToLower().Contains(term))
                );
            }

            var totalRecords = await query.CountAsync();

            // Server-side sorting
            var sortField = request?.SortField?.Trim()?.ToLower();
            var sortAsc = string.Equals(request?.SortOrder, "ASC", StringComparison.OrdinalIgnoreCase);

            query = sortField switch
            {
                "fullname" or "name" => sortAsc ? query.OrderBy(x => x.FullName) : query.OrderByDescending(x => x.FullName),
                "firstname" => sortAsc ? query.OrderBy(x => x.FirstName) : query.OrderByDescending(x => x.FirstName),
                "lastname" => sortAsc ? query.OrderBy(x => x.LastName) : query.OrderByDescending(x => x.LastName),
                "phonenumber" => sortAsc ? query.OrderBy(x => x.PhoneNumber) : query.OrderByDescending(x => x.PhoneNumber),
                "email" => sortAsc ? query.OrderBy(x => x.Email) : query.OrderByDescending(x => x.Email),
                "isactive" => sortAsc ? query.OrderBy(x => x.IsActive) : query.OrderByDescending(x => x.IsActive),
                "createddate" => sortAsc ? query.OrderBy(x => x.CreatedDate) : query.OrderByDescending(x => x.CreatedDate),
                _ => query.OrderByDescending(x => x.CreatedDate).ThenByDescending(x => x.Id)
            };

            // Support both 0-based and 1-based page requests seamlessly
            var pageIndex = (request != null && request.PageNumber > 1) ? request.PageNumber - 1 : 0;
            var pageSize = Math.Max(request?.PageSize ?? 10, 1);
            var pagedUsers = await query.Skip(pageIndex * pageSize).Take(pageSize).ToListAsync();

            var dtoList = pagedUsers.Select(item => new UserDto
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
                MaxCashFloat = item.MaxCashFloat,
                CaptainCompensationType = item.CaptainCompensationType,
                CaptainRate = item.CaptainRate,
                Email = item.Email,
                EmailConfirmed = true,
                Role = role ?? AppRoleName.Customer
            }).ToList();

            if (!role.HasValue && dtoList.Count > 0)
            {
                var userIds = dtoList.Select(x => x.Id).ToList();
                var userRolesMap = await (from ur in db.UserRoles.AsNoTracking()
                                          join ro in db.Roles.AsNoTracking() on ur.RoleId equals ro.Id
                                          where userIds.Contains(ur.UserId)
                                          select new { ur.UserId, ro.Name })
                                          .ToListAsync();

                foreach (var item in dtoList)
                {
                    // A user can have more than one role (for example a
                    // customer account later linked to a merchant). Report
                    // the operational role so the dashboard filter and badge
                    // agree with that account's merchant/delivery purpose.
                    var roleName = userRolesMap
                        .Where(x => x.UserId == item.Id)
                        .OrderBy(x => x.Name == AppRoleName.Merchant.ToString() ? 0 :
                                      x.Name == AppRoleName.Delivery.ToString() ? 1 :
                                      x.Name == AppRoleName.Customer.ToString() ? 2 : 3)
                        .Select(x => x.Name)
                        .FirstOrDefault();
                    if (!string.IsNullOrEmpty(roleName) && Enum.TryParse<AppRoleName>(roleName, true, out var parsedRole))
                    {
                        item.Role = parsedRole;
                    }
                    else
                    {
                        item.Role = AppRoleName.Customer;
                    }
                }
            }

            return new TableResponseModel<UserDto>
            {
                Items = dtoList.ToArray(),
                TotalRecords = totalRecords
            };
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
            var isSyrianPhone = SyrianPhoneIdentity.TryNormalize(fullPhone, out var canonicalPhone);
            if (item.Role == AppRoleName.Merchant && !isSyrianPhone)
                return BadRequest(ApiErr.Create("أدخل رقم موبايل سوري صحيح لحساب التاجر."));
            if (isSyrianPhone)
            {
                var phoneMatch = await SyrianPhoneIdentity.FindAsync(_userManager, canonicalPhone);
                if (phoneMatch.Ambiguous || phoneMatch.User != null)
                    return StatusCode(409, new { error = "PHONE_ALREADY_REGISTERED", errorDescription = "رقم الهاتف مرتبط بحساب موجود بالفعل." });
                fullPhone = canonicalPhone;
            }
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
                EmailConfirmed = true,
                MaxCashFloat = item.MaxCashFloat ?? 5000000m,
                CaptainCompensationType = item.CaptainCompensationType ?? CaptainCompensationType.SalariedEmployee,
                CaptainRate = item.CaptainRate ?? 0m
            };

            if (item.Role == AppRoleName.Merchant && (string.IsNullOrWhiteSpace(item.Password) || item.Password.Trim().Length < 6))
                return BadRequest(ApiErr.Create("أدخل كلمة مرور خاصة بحساب التاجر من 6 أحرف على الأقل."));
            var password = !string.IsNullOrWhiteSpace(item.Password) ? item.Password.Trim() : "123456";
            var result = await _userManager.CreateAsync(entity, password);
            if (!result.Succeeded)
            {
                if (_auditService != null)
                {
                    await _auditService.LogAsync(new AdminAuditLogEntry
                    {
                        Module = "Users",
                        Action = "Create",
                        EntityType = "User",
                        EntityId = fullPhone,
                        Description = $"فشل إنشاء حساب المستخدم: {entity.FullName} ({fullPhone})",
                        Result = "Failed",
                        FailureReason = string.Join(", ", result.Errors.Select(e => e.Description))
                    });
                }
                return BadRequest(result);
            }

            var role = item.Role.ToString();
            var roleResult = await _userManager.AddToRoleAsync(entity, role);
            if (!roleResult.Succeeded)
            {
                await _userManager.DeleteAsync(entity);
                return BadRequest(roleResult);
            }
            _logger.LogInformation("Created New {0} with role {1}", entity.GetType().Name, role);

            if (_auditService != null)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Users",
                    Action = "Create",
                    EntityType = "User",
                    EntityId = entity.Id.ToString(),
                    Description = $"إنشاء حساب مستخدم جديد: {entity.FullName} ({role})",
                    Result = "Success",
                    AfterState = new
                    {
                        entity.Id,
                        entity.FullName,
                        entity.PhoneNumber,
                        entity.Email,
                        Role = role,
                        entity.IsActive
                    }
                });
            }

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

            var currentRoles = await _userManager.GetRolesAsync(entity);
            var beforeState = new
            {
                entity.Id,
                entity.FullName,
                entity.PhoneNumber,
                entity.Email,
                Roles = currentRoles,
                entity.IsActive,
                entity.DefaultLat,
                entity.DefaultLng,
                entity.MaxCashFloat,
                entity.CaptainCompensationType,
                entity.CaptainRate
            };

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
            if (SyrianPhoneIdentity.TryNormalize(fullPhone, out var canonicalPhone))
            {
                var phoneMatch = await SyrianPhoneIdentity.FindAsync(_userManager, canonicalPhone);
                if (phoneMatch.Ambiguous || (phoneMatch.User != null && phoneMatch.User.Id != entity.Id))
                    return StatusCode(409, new { error = "PHONE_ALREADY_REGISTERED", errorDescription = "رقم الهاتف مرتبط بحساب آخر." });
                fullPhone = canonicalPhone;
            }

            entity.FirstName = item.FirstName?.Trim() ?? entity.FirstName;
            entity.LastName = item.LastName?.Trim() ?? entity.LastName;
            entity.FullName = $"{item.FirstName} {item.LastName}".Trim();
            entity.Gender = item.Gender;
            var wasActive = entity.IsActive;
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
            entity.MaxCashFloat = item.MaxCashFloat ?? entity.MaxCashFloat;
            if (item.CaptainCompensationType.HasValue)
            {
                entity.CaptainCompensationType = item.CaptainCompensationType.Value;
            }
            if (item.CaptainRate.HasValue)
            {
                entity.CaptainRate = Math.Max(0m, item.CaptainRate.Value);
            }

            var res = await _userManager.UpdateAsync(entity);
            if (!res.Succeeded)
            {
                if (_auditService != null)
                {
                    await _auditService.LogAsync(new AdminAuditLogEntry
                    {
                        Module = "Users",
                        Action = "Edit",
                        EntityType = "User",
                        EntityId = id.ToString(),
                        Description = $"فشل تحديث بيانات المستخدم: {entity.FullName}",
                        Result = "Failed",
                        FailureReason = string.Join(", ", res.Errors.Select(e => e.Description))
                    });
                }
                return BadRequest(res);
            }

            if (wasActive && !entity.IsActive)
                await NotifyAccountDisabled(entity.Id);

            if (!string.IsNullOrWhiteSpace(item.Password))
            {
                var token = await _userManager.GeneratePasswordResetTokenAsync(entity);
                var passResult = await _userManager.ResetPasswordAsync(entity, token, item.Password.Trim());
                if (!passResult.Succeeded)
                {
                    if (_auditService != null)
                    {
                        await _auditService.LogAsync(new AdminAuditLogEntry
                        {
                            Module = "Users",
                            Action = "ResetPassword",
                            EntityType = "User",
                            EntityId = id.ToString(),
                            Description = $"فشل تعيين كلمة مرور المستخدم: {entity.FullName}",
                            Result = "Failed",
                            FailureReason = string.Join(", ", passResult.Errors.Select(e => e.Description))
                        });
                    }
                    return BadRequest(passResult);
                }
            }

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

            if (_auditService != null)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Users",
                    Action = "Edit",
                    EntityType = "User",
                    EntityId = entity.Id.ToString(),
                    Description = $"تعديل بيانات المستخدم: {entity.FullName} ({role})",
                    Result = "Success",
                    BeforeState = beforeState,
                    AfterState = new
                    {
                        entity.Id,
                        entity.FullName,
                        entity.PhoneNumber,
                        entity.Email,
                        Role = role,
                        entity.IsActive,
                        entity.DefaultLat,
                        entity.DefaultLng
                    }
                });
            }

            return entity.Id;
        }

        [HttpPost("{id:guid}/ResetPassword")]
        public async Task<IActionResult> ResetMerchantPassword(
            Guid id,
            [FromBody] AdminResetMerchantPasswordRequest request)
        {
            if (request == null || string.IsNullOrWhiteSpace(request.NewPassword) || request.NewPassword.Trim().Length < 6)
            {
                return BadRequest(new { error = "كلمة المرور يجب ألا تقل عن 6 أحرف." });
            }

            var user = await _userManager.FindByIdAsync(id.ToString());
            if (user == null || !await _userManager.IsInRoleAsync(user, AppRoleName.Merchant.ToString()))
            {
                return NotFound();
            }

            var token = await _userManager.GeneratePasswordResetTokenAsync(user);
            var result = await _userManager.ResetPasswordAsync(user, token, request.NewPassword.Trim());
            if (!result.Succeeded)
            {
                if (_auditService != null)
                {
                    await _auditService.LogAsync(new AdminAuditLogEntry
                    {
                        Module = "Users",
                        Action = "ResetPassword",
                        EntityType = "User",
                        EntityId = id.ToString(),
                        Description = $"فشل إعادة تعيين كلمة مرور حساب التاجر: {user.FullName}",
                        Result = "Failed",
                        FailureReason = string.Join(", ", result.Errors.Select(error => error.Description))
                    });
                }

                return BadRequest(result);
            }

            if (_auditService != null)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Users",
                    Action = "ResetPassword",
                    EntityType = "User",
                    EntityId = id.ToString(),
                    Description = $"إعادة تعيين كلمة مرور حساب التاجر: {user.FullName}",
                    Result = "Success"
                });
            }

            return NoContent();
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
            if (user == null) return NotFound();
            user.IsActive = true;
            await _userManager.UpdateAsync(user);

            if (_auditService != null)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Users",
                    Action = "Enable",
                    EntityType = "User",
                    EntityId = id.ToString(),
                    Description = $"تفعيل حساب المستخدم: {user.FullName}",
                    Result = "Success"
                });
            }

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
            if (user == null) return NotFound();
            user.IsActive = false;
            var update = await _userManager.UpdateAsync(user);
            if (!update.Succeeded) return BadRequest(update.Errors);

            // Foreground clients can leave immediately. The API check remains
            // authoritative when FCM is delayed or unavailable.
            await NotifyAccountDisabled(user.Id);

            if (_auditService != null)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Users",
                    Action = "Disable",
                    EntityType = "User",
                    EntityId = id.ToString(),
                    Description = $"تعطيل حساب المستخدم: {user.FullName}",
                    Result = "Success"
                });
            }

            return true;
        }

        private async Task NotifyAccountDisabled(Guid userId)
        {
            if (_notificationService == null) return;
            await _notificationService.SendPushNotification(new Notification
            {
                Url = "account-disabled",
                EntityData = userId.ToString(),
                NotificationType = NotificationType.GlobalNotification
            }, new[] { userId }, saveNotification: false, suppressedNotification: true);
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
                if (_auditService != null)
                {
                    await _auditService.LogAsync(new AdminAuditLogEntry
                    {
                        Module = "Users",
                        Action = "Delete",
                        EntityType = "User",
                        EntityId = id.ToString(),
                        Description = $"محاولة حذف المشرف الرئيسي للنظام: {user.FullName}",
                        Result = "Failed",
                        FailureReason = "لا يمكن حذف المشرف الرئيسي للنظام."
                    });
                }
                return BadRequest("Cannot delete root admin user");
            }
            user.IsActive = false;
            user.DeletionDate = DateTime.UtcNow;
            await _userManager.UpdateAsync(user);

            if (_auditService != null)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Users",
                    Action = "Delete",
                    EntityType = "User",
                    EntityId = id.ToString(),
                    Description = $"حذف/أرشفة حساب المستخدم: {user.FullName}",
                    Result = "Success"
                });
            }

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
            return (await _service.ListFromRoles(AppRoleName.Merchant.ToString()))
                .Where(x => x.DeletionDate == null)
                .Select(x => new UserDto
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
                MaxCashFloat = x.MaxCashFloat,
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
            return (await _service.ListFromRoles(AppRoleName.Delivery.ToString()))
                .Where(x => x.DeletionDate == null)
                .Select(x => new UserDto
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
                MaxCashFloat = x.MaxCashFloat,
                CaptainCompensationType = x.CaptainCompensationType,
                CaptainRate = x.CaptainRate,
                Email = x.Email,
                EmailConfirmed = x.EmailConfirmed
            }).ToArray();
        }



        [HttpGet]
        [Route("Roles")]
        public ActionResult<TagVal[]> Roles() =>
            TagVal.Create<AppRoleName>();
    }

    public sealed class AdminResetMerchantPasswordRequest
    {
        [Required]
        [MinLength(6)]
        public string NewPassword { get; set; }
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
