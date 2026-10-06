using Microsoft.Extensions.Caching.Memory;
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
using System.Data;
using System.Text.RegularExpressions;
using Modules.Accounting.Data;
using Modules.Accounting.Services;
using Modules.Accounting.Entities;
using App.Orders.Data;
using App.Catalog.Data;
using Modules.Orders.Entities;
using App.Shared.Entities.Domain;

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
        private readonly AccountingDbContext _accounting;
        private readonly OrdersDbContext _orders;
        private readonly CatalogDbContext _catalog;
        private readonly ILedgerService _ledger;
        private readonly IMemoryCache _cache;
        private Guid? _disableNotice;

        public UsersController(UserManager<AppUser> userManager, IUserService service, ITagService tagService, IAppUnitOfWork uow, IMapper mapper, IWebHostEnvironment env, ILogger<UsersController> logger,
                                    RoleManager<SolRole> roleManager,
                                    ITrackableRepository<AppUser> userRepo,
                                    ITrackableRepository<SolUserRole> userRoleRepo,
                                    IAdminAuditService auditService = null,
                                    INotificationService notificationService = null,
                                    AccountingDbContext accounting = null, OrdersDbContext orders = null,
                                    CatalogDbContext catalog = null, ILedgerService ledger = null, IMemoryCache cache = null)
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
            _accounting = accounting; _orders = orders; _catalog = catalog; _ledger = ledger; _cache = cache;
        }

        /// <summary>
        /// Get a paged/filtered/ordered list of Users
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Route("DataTable")]
        public async Task<ActionResult<TableResponseModel<UserDto>>> DataTable([FromBody] MetronicTable request,
            [FromQuery] AppRoleName? role = null, [FromQuery] bool? isActive = null)
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
            var adminIds=await db.Roles.Where(r=>r.Name==AppRoleName.Admin.ToString()).Select(r=>r.Id).ToListAsync();
            var merchantIds=await db.Roles.Where(r=>r.Name==AppRoleName.Merchant.ToString()).Select(r=>r.Id).ToListAsync();
            var deliveryIds=await db.Roles.Where(r=>r.Name==AppRoleName.Delivery.ToString()).Select(r=>r.Id).ToListAsync();
            query=query.Where(u=>!db.UserRoles.Any(r=>r.UserId==u.Id && adminIds.Contains(r.RoleId)));
            if(role==AppRoleName.Customer || role==AppRoleName.Delivery)
                query=query.Where(u=>!db.UserRoles.Any(r=>r.UserId==u.Id && merchantIds.Contains(r.RoleId)));
            if(role==AppRoleName.Customer)
                query=query.Where(u=>!db.UserRoles.Any(r=>r.UserId==u.Id && deliveryIds.Contains(r.RoleId)));
            if(isActive.HasValue) query=query.Where(u=>u.IsActive==isActive.Value);
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
            var staffCount=await query.CountAsync(u=>db.UserRoles.Any(r=>r.UserId==u.Id && (merchantIds.Contains(r.RoleId) || deliveryIds.Contains(r.RoleId))));
            var summary=new {Total=totalRecords,Active=await query.CountAsync(u=>u.IsActive),Customers=totalRecords-staffCount,Staff=staffCount};

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

            query = ((IOrderedQueryable<AppUser>)query).ThenByDescending(x => x.Id);
            // API pages are one-based; zero remains a legacy alias for the first page.
            var pageIndex = (request != null && request.PageNumber > 1) ? request.PageNumber - 1 : 0;
            var pageSize = Math.Clamp(request?.PageSize ?? 10, 1, 1000);
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
                Lang = item.Lang,
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

            return Ok(new { Items=dtoList.ToArray(),TotalRecords=totalRecords,TotalRecordsFiltered=totalRecords,Summary=summary });
        }

        /// <summary>
        /// Create a new User
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        public async Task<ActionResult<Guid>> Create(UserDto item)
        {
            var validation=ValidateUserInput(item, true);
            if(validation!=null) return BadRequest(ApiErr.Create(validation));
            return await IdentityTransactionAsync(()=>CreateCore(item));
        }

        private async Task<ActionResult<Guid>> CreateCore(UserDto item)
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
            if(!Regex.IsMatch(fullPhone, @"^\+[1-9][0-9]{7,14}$")) return BadRequest(ApiErr.Create("أدخل رقم هاتف صحيحاً مع رمز الدولة."));
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
                FullName = $"{item.FirstName?.Trim()} {item.LastName?.Trim()}".Trim(),
                Gender = item.Gender,
                IsActive = item.IsActive,
                ProfilePhoto = item.ProfilePhoto,
                Birthday = item.Birthday,
                PhoneNumber = fullPhone,
                CountryPhoneCode = countryCode,
                Lang = string.IsNullOrWhiteSpace(item.Lang) ? "ar" : item.Lang.Trim(),
                Email = email,
                UserName = fullPhone,
                EmailConfirmed = true,
                MaxCashFloat = item.MaxCashFloat ?? 5000000m,
                CaptainCompensationType = item.Role==AppRoleName.Delivery ? item.CaptainCompensationType ?? CaptainCompensationType.SalariedEmployee : CaptainCompensationType.SalariedEmployee,
                CaptainRate = item.Role==AppRoleName.Delivery && (item.CaptainCompensationType ?? CaptainCompensationType.SalariedEmployee)!=CaptainCompensationType.SalariedEmployee ? item.CaptainRate ?? 0m : 0m
            };

            if (item.Role == AppRoleName.Merchant && (string.IsNullOrWhiteSpace(item.Password) || item.Password.Trim().Length < 6))
                return BadRequest(ApiErr.Create("أدخل كلمة مرور خاصة بحساب التاجر من 6 أحرف على الأقل."));
            var password = item.Password.Trim();
            var result = await _userManager.CreateAsync(entity, password);
            if (!result.Succeeded)
            {
                if (_auditService != null)
                {
                    await TryAuditAsync(new AdminAuditLogEntry
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
                await TryAuditAsync(new AdminAuditLogEntry
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
            var validation=ValidateUserInput(item, false);
            if(validation!=null) return BadRequest(ApiErr.Create(validation));
            if(_accounting!=null && _ledger!=null)
                return await new DriverFinancialSafetyService(_accounting,_ledger,_uow.Context,_orders).WithDriverLockAsync(id,()=>IdentityTransactionAsync(()=>EditCore(id,item)));
            return await IdentityTransactionAsync(()=>EditCore(id,item));
        }

        
        private async Task SyncMerchantProfileAsync(Guid userId, string fullName, string phoneNumber, bool isActive)
        {
            if (_catalog == null) return;
            try
            {
                var ownedMerchants = await _catalog.Merchants
                    .Where(m => m.OwnerId == userId && m.DeletionDate == null)
                    .ToListAsync();
                if (ownedMerchants.Any())
                {
                    foreach (var m in ownedMerchants)
                    {
                        if (!string.IsNullOrWhiteSpace(fullName))
                        {
                            m.OwnerName = fullName.Trim();
                        }
                        if (!string.IsNullOrWhiteSpace(phoneNumber))
                        {
                            m.Phone1 = phoneNumber.Trim();
                        }
                        m.Active = isActive;

                        _cache?.Remove($"ActiveMerchantPrices_{m.Id}");
                        _cache?.Remove($"AllMerchantPrices_{m.Id}");
                    }
                    await _catalog.SaveChangesAsync();

                    _cache?.Remove("RestaurantCategoriesCustomerCache");
                    _cache?.Remove("GetValidMerchants");
                }
            }
            catch (Exception ex)
            {
                _logger?.LogWarning(ex, "Failed to sync merchant profile from user {0}", userId);
            }
        }

        private async Task<ActionResult<Guid>> EditCore(Guid id, UserDto item)
        {
            var entity = await _userManager.Users.FirstOrDefaultAsync(x => x.Id == id);
            if (entity == null || entity.DeletionDate!=null) return NotFound();

            var currentRoles = await _userManager.GetRolesAsync(entity);
            var effectiveType = item.CaptainCompensationType ?? entity.CaptainCompensationType;
            var effectiveRate = item.CaptainRate ?? entity.CaptainRate;
            if(item.Role == AppRoleName.Delivery && effectiveType == CaptainCompensationType.Percentage && effectiveRate > 100m)
                return BadRequest(ApiErr.Create("نسبة المندوب لا يمكن أن تتجاوز 100%."));
            if(currentRoles.Contains(AppRoleName.Admin.ToString())) return BadRequest(ApiErr.Create("حسابات الأدمن لا تُعدّل من قائمة مستخدمي التطبيقات."));
            if(currentRoles.Contains(AppRoleName.Merchant.ToString()) && item.Role!=AppRoleName.Merchant && _catalog!=null && await _catalog.Merchants.AnyAsync(m=>m.OwnerId==id))
                return BadRequest(ApiErr.Create("هذا المستخدم يملك متجراً. انقل ملكية متاجره قبل تغيير دوره."));
            if(currentRoles.Contains(AppRoleName.Delivery.ToString()) && item.Role!=AppRoleName.Delivery && await HasDriverObligations(id))
                return BadRequest(ApiErr.Create("للمندوب عهدة أو أرباح أو طلبات قيد التنفيذ. أكملها وسوِّ حسابه قبل تغيير دوره."));
            foreach(var validator in _userManager.PasswordValidators)
                if(!string.IsNullOrWhiteSpace(item.Password)) {var result=await validator.ValidateAsync(_userManager,entity,item.Password.Trim());if(!result.Succeeded)return BadRequest(result);}
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
            if(!Regex.IsMatch(fullPhone, @"^\+[1-9][0-9]{7,14}$")) return BadRequest(ApiErr.Create("أدخل رقم هاتف صحيحاً مع رمز الدولة."));
            if(item.Role==AppRoleName.Merchant && !SyrianPhoneIdentity.TryNormalize(fullPhone,out _)) return BadRequest(ApiErr.Create("أدخل رقم موبايل سوري صحيح لحساب التاجر."));
            if (SyrianPhoneIdentity.TryNormalize(fullPhone, out var canonicalPhone))
            {
                var phoneMatch = await SyrianPhoneIdentity.FindAsync(_userManager, canonicalPhone);
                if (phoneMatch.Ambiguous || (phoneMatch.User != null && phoneMatch.User.Id != entity.Id))
                    return StatusCode(409, new { error = "PHONE_ALREADY_REGISTERED", errorDescription = "رقم الهاتف مرتبط بحساب آخر." });
                fullPhone = canonicalPhone;
            }

            entity.FirstName = item.FirstName?.Trim() ?? entity.FirstName;
            entity.LastName = item.LastName?.Trim() ?? entity.LastName;
            entity.FullName = $"{entity.FirstName} {entity.LastName}".Trim();
            var wasActive = entity.IsActive;
            entity.IsActive = item.IsActive;
            entity.ProfilePhoto = item.ProfilePhoto;
            entity.PhoneNumber = fullPhone;
            entity.CountryPhoneCode = countryCode;
            if (!string.IsNullOrWhiteSpace(item.Email))
            {
                entity.Email = item.Email.Trim();
            }
            entity.UserName = fullPhone;
            entity.EmailConfirmed = true;
            if(!string.IsNullOrWhiteSpace(item.Lang)) entity.Lang=item.Lang.Trim();
            entity.MaxCashFloat = item.MaxCashFloat ?? entity.MaxCashFloat;
            if (item.CaptainCompensationType.HasValue)
            {
                entity.CaptainCompensationType = item.CaptainCompensationType.Value;
            }
            if (item.CaptainRate.HasValue)
            {
                entity.CaptainRate = item.CaptainRate.Value;
            }
            if(item.Role!=AppRoleName.Delivery || entity.CaptainCompensationType==CaptainCompensationType.SalariedEmployee) {entity.CaptainRate=0m;if(item.Role!=AppRoleName.Delivery)entity.CaptainCompensationType=CaptainCompensationType.SalariedEmployee;}

            var res = await _userManager.UpdateAsync(entity);
            if (!res.Succeeded)
            {
                if (_auditService != null)
                {
                    await TryAuditAsync(new AdminAuditLogEntry
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

            if (!string.IsNullOrWhiteSpace(item.Password))
            {
                var token = await _userManager.GeneratePasswordResetTokenAsync(entity);
                var passResult = await _userManager.ResetPasswordAsync(entity, token, item.Password.Trim());
                if (!passResult.Succeeded)
                {
                    if (_auditService != null)
                    {
                        await TryAuditAsync(new AdminAuditLogEntry
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

            var role = item.Role.ToString();
            if(!currentRoles.Contains(role)) {res=await _userManager.AddToRoleAsync(entity,role);if(!res.Succeeded)return BadRequest(res);}
            var removedRoles=currentRoles.Where(r=>(r==AppRoleName.Merchant.ToString() || r==AppRoleName.Delivery.ToString()) && r!=role).ToArray();
            if(removedRoles.Length>0) {res=await _userManager.RemoveFromRolesAsync(entity,removedRoles);if(!res.Succeeded)return BadRequest(res);}

            if (_auditService != null)
            {
                await TryAuditAsync(new AdminAuditLogEntry
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

            await SyncMerchantProfileAsync(entity.Id, entity.FullName, fullPhone, entity.IsActive);
            if(wasActive && !entity.IsActive) _disableNotice=entity.Id;
            return entity.Id;
        }

        private async Task<ActionResult<Guid>> IdentityTransactionAsync(Func<Task<ActionResult<Guid>>> action)
        {
            ActionResult<Guid> result;
            await using(var transaction=_uow?.Context?.Database.IsRelational()==true ? await _uow.Context.Database.BeginTransactionAsync(IsolationLevel.Serializable) : null) {
                result=await action();
                if(result.Result==null && result.Value!=Guid.Empty && transaction!=null) await transaction.CommitAsync();
            }
            if(result.Result==null && result.Value!=Guid.Empty && _disableNotice.HasValue) await NotifyAccountDisabled(_disableNotice.Value);
            return result;
        }

        private async Task<bool> HasDriverObligations(Guid id)
        {
            if(_accounting!=null) {
                if(await _accounting.SettlementRequests.AnyAsync(r=>r.RequestedByUserId==id && (r.Status==SettlementRequestStatus.Pending || r.Status==SettlementRequestStatus.Approved))) return true;
                var currencies=await _accounting.Accounts.Where(a=>a.OwnerUserId==id).Select(a=>a.Currency).Distinct().ToListAsync();
                if(_ledger!=null) foreach(var currency in currencies)
                    if(await _ledger.GetUserCashFloatBalanceAsync(id,currency)!=0m || await _ledger.GetUserEarningsBalanceAsync(id,currency)!=0m) return true;
            }
            if(_orders!=null && await _orders.Orders.AnyAsync(o=>o.DeliveryId==id && (o.AccountingStatus==OrderAccountingStatus.PendingAccounting || o.AccountingStatus==OrderAccountingStatus.Failed ||
                (o.DeliveredAt==null && o.OrderStatus==OrderStatus.Success && o.OrderDetails.Any(d=>d.OrderDetailStatus==OrderDetailStatus.Pending || d.OrderDetailStatus==OrderDetailStatus.MerchantAccepted || d.OrderDetailStatus==OrderDetailStatus.ReadyForPickup || d.OrderDetailStatus==OrderDetailStatus.ShippingStarted || d.OrderDetailStatus==OrderDetailStatus.CustomerPending))))) return true;
            return _uow!=null && await _uow.Context.SupportMessages.AnyAsync(e=>e.ErrandDriverUserId==id && (e.ErrandStatus==ErrandStatus.Assigned || e.ErrandStatus==ErrandStatus.Purchased || e.ErrandStatus==ErrandStatus.PurchasePending || e.ErrandStatus==ErrandStatus.DeliveryPending || e.ErrandStatus==ErrandStatus.ReturnPending));
        }

        public static string ValidateUserInput(UserDto item,bool creating)
        {
            if(item==null) return "بيانات المستخدم مطلوبة.";
            if(item.Role!=AppRoleName.Customer && item.Role!=AppRoleName.Merchant && item.Role!=AppRoleName.Delivery) return "اختر دوراً صالحاً لمستخدم التطبيق.";
            if(string.IsNullOrWhiteSpace(item.FirstName) || string.IsNullOrWhiteSpace(item.LastName) || item.FirstName.Trim().Length>100 || item.LastName.Trim().Length>100) return "الاسم الأول واسم العائلة مطلوبان وبحد أقصى 100 حرف لكل منهما.";
            if(string.IsNullOrWhiteSpace(item.PhoneNumber)) return "رقم الهاتف مطلوب.";
            if(!string.IsNullOrWhiteSpace(item.Email) && !new EmailAddressAttribute().IsValid(item.Email.Trim())) return "أدخل بريداً إلكترونياً صحيحاً.";
            if((creating || !string.IsNullOrWhiteSpace(item.Password)) && (item.Password?.Trim().Length ?? 0)<6) return "كلمة المرور يجب ألا تقل عن 6 أحرف.";
            if(item.MaxCashFloat is decimal limit && (limit<0m || limit>1000000000m || limit!=decimal.Round(limit,2))) return "حد العهدة يجب أن يكون بين صفر ومليار وبحد أقصى منزلتين عشريتين.";
            var type=item.CaptainCompensationType ?? CaptainCompensationType.SalariedEmployee;
            var rate=item.CaptainRate ?? 0m;
            if(!Enum.IsDefined(typeof(CaptainCompensationType),type) || rate<0m || rate>1000000000m || rate!=decimal.Round(rate,2) || (type==CaptainCompensationType.Percentage && rate>100m)) return "طريقة حساب المندوب أو قيمتها غير صالحة. النسبة بين صفر و100% والقيم بحد أقصى منزلتين عشريتين.";
            if(!string.IsNullOrWhiteSpace(item.Lang) && !new[]{"ar","en","tr"}.Contains(item.Lang.Trim())) return "لغة المستخدم غير صالحة.";
            return null;
        }

        private async Task TryAuditAsync(AdminAuditLogEntry entry)
        {
            try {await _auditService.LogAsync(entry);} catch(Exception ex) {_logger?.LogWarning(ex,"Unable to write user audit entry");}
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
            if (user == null || user.DeletionDate != null || !await _userManager.IsInRoleAsync(user, AppRoleName.Merchant.ToString()))
            {
                return NotFound();
            }

            var token = await _userManager.GeneratePasswordResetTokenAsync(user);
            var result = await _userManager.ResetPasswordAsync(user, token, request.NewPassword.Trim());
            if (!result.Succeeded)
            {
                if (_auditService != null)
                {
                    await TryAuditAsync(new AdminAuditLogEntry
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
                await TryAuditAsync(new AdminAuditLogEntry
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
            if (user == null || user.DeletionDate!=null) return NotFound();
            if(await _userManager.IsInRoleAsync(user,AppRoleName.Admin.ToString())) return BadRequest(ApiErr.Create("حساب الأدمن لا يُغيّر من قائمة مستخدمي التطبيقات."));
            user.IsActive = true;
            var update=await _userManager.UpdateAsync(user);
            if(!update.Succeeded) return BadRequest(ApiErr.Create(string.Join("، ", update.Errors.Select(e=>e.Description))));
            await SyncMerchantProfileAsync(user.Id, user.FullName, user.PhoneNumber, true);

            if (_auditService != null)
            {
                await TryAuditAsync(new AdminAuditLogEntry
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
            if (user == null || user.DeletionDate!=null) return NotFound();
            if(await _userManager.IsInRoleAsync(user,AppRoleName.Admin.ToString())) return BadRequest(ApiErr.Create("لا يمكن تعطيل حساب الأدمن من قائمة مستخدمي التطبيقات."));
            user.IsActive = false;
            var update = await _userManager.UpdateAsync(user);
            if (!update.Succeeded) return BadRequest(ApiErr.Create(string.Join("، ", update.Errors.Select(e=>e.Description))));
            await SyncMerchantProfileAsync(user.Id, user.FullName, user.PhoneNumber, false);

            // Foreground clients can leave immediately. The API check remains
            // authoritative when FCM is delayed or unavailable.
            await NotifyAccountDisabled(user.Id);

            if (_auditService != null)
            {
                await TryAuditAsync(new AdminAuditLogEntry
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
            try {await _notificationService.SendPushNotification(new Notification
            {
                Url = "account-disabled",
                EntityData = userId.ToString(),
                NotificationType = NotificationType.GlobalNotification
            }, new[] { userId }, saveNotification: false, suppressedNotification: true);} catch(Exception ex) {_logger?.LogWarning(ex,"Unable to notify disabled account");}
        }

        /// <summary>
        /// Delete User
        /// </summary>
        /// <returns></returns>
        [HttpDelete]
        [Route("{id}")]
        public async Task<ActionResult<bool>> Delete(Guid id)
        {
            if(_accounting!=null && _ledger!=null)
                return await new DriverFinancialSafetyService(_accounting,_ledger,_uow.Context,_orders).WithDriverLockAsync(id,()=>DeleteCore(id));
            return await DeleteCore(id);
        }

        private async Task<ActionResult<bool>> DeleteCore(Guid id)
        {
            var user = await _userManager.Users.FirstOrDefaultAsync(x => x.Id == id);
            if (user == null) return NotFound();
            if (user.Email == AppDomainHelper.AdminEmail || await _userManager.IsInRoleAsync(user,AppRoleName.Admin.ToString()))
            {
                if (_auditService != null)
                {
                    await TryAuditAsync(new AdminAuditLogEntry
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
            if(await _userManager.IsInRoleAsync(user,AppRoleName.Delivery.ToString()) && await HasDriverObligations(id))
                return BadRequest(ApiErr.Create("لا يمكن أرشفة المندوب قبل إنهاء طلباته وتسوية العهدة والأرباح. يمكنك تعطيل دخوله مؤقتاً."));
            if(await _userManager.IsInRoleAsync(user,AppRoleName.Merchant.ToString()) && _catalog!=null && await _catalog.Merchants.AnyAsync(m=>m.OwnerId==id))
                return BadRequest(ApiErr.Create("انقل ملكية متاجر التاجر قبل أرشفة حسابه حتى تبقى المستحقات مرتبطة بصاحبها. يمكنك تعطيل دخوله مؤقتاً."));
            user.IsActive = false;
            user.DeletionDate = DateTime.UtcNow;
            var update=await _userManager.UpdateAsync(user);
            if(!update.Succeeded) return BadRequest(ApiErr.Create(string.Join("، ", update.Errors.Select(e=>e.Description))));
            await NotifyAccountDisabled(user.Id);

            if (_auditService != null)
            {
                await TryAuditAsync(new AdminAuditLogEntry
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
