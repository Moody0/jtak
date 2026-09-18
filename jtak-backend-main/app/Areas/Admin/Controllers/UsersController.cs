using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using AutoMapper;
using App.Areas.Admin.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using App.Extensions;
using App.Helpers;
using App.Models.AccountViewModels;
using App.Resources;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Hosting;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Logging;
using App.Controllers;
using Solf.Services;
using URF.Core.Abstractions;
using App.Shared.Services;
using App.Shared.Entities.Enums;
using App.Shared.Entities;
using App.Shared.Services.Extentions;
using App.Shared.Entities.Resources;
using App.Shared.Services.Helpers;
using Solf.Models;
using Solf.Extensions;

namespace App.Areas.Admin.Controllers
{
    [Authorize(nameof(AppPermissionKey.AdminPermission))]
    [Area("Admin")]
    public class UsersController : BaseController
    {
        private readonly IUserService _userService;
        private readonly INotificationService _notificationService;
        private readonly IEmailService _emailService;
        private readonly SignInManager<AppUser> _signInManager;
        private readonly IWebHostEnvironment _env;
        private readonly ISessionHelper _sessionHelper;

        public UsersController(IUnitOfWork unitOfWorkAsync,
                                    ILogger<UsersController> logger,
                                    UserManager<AppUser> userManager,
                                    IMapper mapper,
                                    IWebHostEnvironment hostingEnvironment,
                                    IUserService userService,
                                    INotificationService notificationService,
                                    IEmailService emailService,
                                    ISessionHelper sessionHelper,
                                    SignInManager<AppUser> signInManager) : base(unitOfWorkAsync, mapper, logger, userManager)
        {
            _env = hostingEnvironment;
            _userService = userService;
            _notificationService = notificationService;
            _emailService = emailService;
            _sessionHelper = sessionHelper;
            _signInManager = signInManager;
        }

        #region Index
        public IActionResult Index()
        {
            ViewBag.Title = _Nav.Users;
            return View();
        }
        [HttpPost]
        public async Task<ActionResult<DataTablesResponse>> Index(AppRoleName? id, DataTablesRequest request)
        {
            if (id.HasValue)
            {
                return (await UserManager.GetUsersInRoleAsync(id.ToString())).ListGridAsync(request,
                    item => Mapper.Map<UserDto>(item),
                    x => x.Email == null || x.Email != AppDomainHelper.AdminEmail);
            }
            else
            {
                return await _userService.ListDataTable(request, item => Mapper.Map<UserDto>(item), x => x.Email == null || x.Email != AppDomainHelper.AdminEmail);
            }
        }
        #endregion

        #region Create Admin
        public async Task<IActionResult> CreateAdmin()
        {
            ViewBag.Title = _Common.Create;
            var model = new RegisterVm { };
            await InitViewBags(model);
            return View(model);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> CreateCreateAdmin(RegisterVm vm)
        {
            if (ModelState.IsValid)
            {
                var user = new AppUser()
                {
                    FirstName = vm.FirstName,
                    LastName = vm.LastName,
                    FullName = $"{vm.FirstName} {vm.LastName}",
                    Gender = vm.Gender,
                    IsActive = true,
                    ProfilePhoto = vm.ProfilePhoto,
                    Birthday = vm.Birthday,
                    PhoneNumber = vm.PhoneNumber,
                    Email = vm.Email,
                    UserName = vm.Email,
                    EmailConfirmed = true
                };

                try
                {
                    var result = await UserManager.CreateAsync(user, vm.Password);
                    if (result.Succeeded)
                    {
                        Logger.LogInformation($"Create New User ({AppRoleName.Admin})");
                        result = await UserManager.AddToRoleAsync(user, AppRoleName.Admin.ToString());

                        var code = await UserManager.GenerateEmailConfirmationTokenAsync(user); // valid for 1 day only
                        var callbackUrl = Url.EmailConfirmationLink(user.Id, code);
                        await _emailService.SendEmailConfirmationAsync(user.FirstName, user.Email, callbackUrl);
                        return RedirectToAction("Index", "Users", new { area = "Admin" });
                    }

                    foreach (var err in result.Errors) ModelState.AddModelError("", err.Description);
                }
                catch (DbUpdateException e)
                {
                    ModelState.AddModelError("", _env.IsDevelopment() ? e.ToString() : _Common.Err_TryLater);
                    Logger.LogError(e, e.ToString());
                }
            }
            ViewBag.Title = _Common.Create;
            await InitViewBags(vm);
            return View(vm);
        }
        #endregion

        #region Edit
        public async Task<IActionResult> Edit(string id)
        {
            if (id == null) return NotFound();
            var target = await UserManager.FindByIdAsync(id);
            if (target == null) return NotFound();

            ViewBag.Title = _Common.Edit;
            var model = Mapper.Map<AppUser, UserDto>(target);
            //model.Role = (await UserManager.GetRoleNamesAsync(target)).FirstOrDefault();
            await InitViewBags(model);
            return View(model);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Edit(Guid id, UserDto vm, AppRoleName role)
        {
            if (vm.Id != id) return NotFound();
            var target = await UserManager.FindByIdAsync(id.ToString());
            if (target == null) return NotFound();

            if (ModelState.IsValid)
            {
                try
                {
                    var resendEmail = !target.EmailConfirmed && target.Email != vm.Email;

                    target.FirstName = vm.FirstName;
                    target.LastName = vm.LastName;
                    target.FullName = $"{vm.FirstName} {vm.LastName}";
                    target.Email = vm.Email;
                    target.UserName = vm.Email;
                    target.PhoneNumber = vm.PhoneNumber;
                    target.ProfilePhoto = vm.ProfilePhoto;
                    
                    target.PhoneNumber = vm.PhoneNumber;

                    var result = await UserManager.UpdateAsync(target);

                    if (!result.Succeeded) return RedirectToAction(nameof(Index));

                    Logger.LogInformation("Edit User {0}", target.Email);

                    if (resendEmail)
                    {
                        var code = await UserManager.GenerateEmailConfirmationTokenAsync(target);
                        var callbackUrl = Url.EmailConfirmationLink(target.Id, code);
                        await _emailService.SendEmailConfirmationAsync(target.FirstName, target.Email, callbackUrl);
                    }
                    return RedirectToAction("Index", "Users", new { area = "Admin" });

                }
                catch (DbUpdateConcurrencyException e)
                {
                    ModelState.AddModelError("", _env.IsDevelopment() ? e.ToString() : _Common.Err_TryLater);
                    Logger.LogError(e, e.ToString());
                }
            }
            ViewBag.Title = _Common.Edit;
            await InitViewBags(vm);
            return View(vm);
        }
        #endregion

        #region Permissions

        public async Task<IActionResult> Permissions(string id)
        {
            if (id == null) return NotFound();
            var target = await UserManager.FindByIdAsync(id);
            if (target == null) return NotFound();

            ViewBag.UserEmail = target.Email;
            ViewBag.UserDisplayName = target.FirstName + " " + target.LastName;
            ViewBag.Title = _Common.Edit;
            var model = await UserPermissions(target);
            return View(model);
        }

        private async Task<List<UserPermission>> UserPermissions(AppUser user)
        {
            var keys = Enum.GetValues<AppPermissionKey>();
            var cs = (await UserManager.GetClaimsAsync(user));
            var claims = cs.Where(x => keys.Any(k => k.ToString() == x.Type))?.ToList();
            var result = new List<UserPermission>();
            foreach (var key in keys)
            {
                var claim = claims.FirstOrDefault(c => c.Type == key.ToString());
                var value = claim?.Value == "true" ? UserPermissionValue.Allow : claim?.Value == "false" ? UserPermissionValue.Deny : UserPermissionValue.NoChange;
                result.Add(new UserPermission()
                {
                    AppPermissionKey = key,
                    UserPermissionValue = value
                });
            }

            return result;
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Permissions(string id, UserPermission[] permissions)
        {
            if (id == null) return NotFound();
            var target = await UserManager.FindByIdAsync(id);
            if (target == null) return NotFound();
            var keys = Enum.GetValues<AppPermissionKey>();
            var oldclaims = (await UserManager.GetClaimsAsync(target)).Where(x => keys.Any(k => k.ToString() == x.Type))?.ToList();
            var newclaims = permissions.Where(x => x.UserPermissionValue != UserPermissionValue.NoChange)
                                        .Select(x => new Claim(x.AppPermissionKey.ToString(), (x.UserPermissionValue == UserPermissionValue.Allow).ToString().ToLower(), "bool", "AppPermissionKey"))
                                        .ToList();
            if (ModelState.IsValid)
            {
                try
                {
                    // Remove existing (AppPermissionKey) claims
                    var result = await UserManager.RemoveClaimsAsync(target, oldclaims);
                    if (result.Succeeded) Logger.LogInformation("Remove User Claims");

                    // Remove new (AppPermissionKey) claims
                    result = await UserManager.AddClaimsAsync(target, newclaims);
                    if (result.Succeeded) Logger.LogInformation("Add User Claims");

                    // Update security stamp to force user sign-in and start new session
                    result = await UserManager.UpdateSecurityStampAsync(target);
                    if (result.Succeeded) Logger.LogInformation("Remove User Claims");

                    return RedirectToAction("Index", "Users", new { area = "Admin" });
                }
                catch (DbUpdateException e)
                {
                    ModelState.AddModelError("", _env.IsDevelopment() ? e.ToString() : _Common.Err_TryLater);
                    Logger.LogError(e, e.ToString());
                }
            }
            ViewBag.Title = _AppUser.UserPermissions;
            ViewBag.UserEmail = target.Email;
            ViewBag.UserDisplayName = target.FirstName + " " + target.LastName;
            var model = await UserPermissions(target);
            return View(model);
        }
        #endregion

        #region Delete
        public async Task<IActionResult> Delete(string id)
        {
            if (id == null) return NotFound();

            var target = await UserManager.FindByIdAsync(id);
            if (target == null)
            {
                return NotFound();
            }

            ViewBag.Title = _Common.Delete;
            var model = Mapper.Map<AppUser, UserDto>(target);
            return View(model);
        }

        [HttpPost, ActionName("Delete")]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> DeleteConfirmed(string id)
        {
            try
            {
                var user = await UserManager.FindByIdAsync(id);
                user.Email += $"deletedon{DateTime.UtcNow:O}";
                user.UserName += $"deletedon{DateTime.UtcNow:O}";
                await UserManager.UpdateSecurityStampAsync(user);
                await UserManager.DeleteAsync(user);
                await UnitOfWork.SaveChangesAsync();
                Logger.LogInformation("Deleted TransLog");
            }
            catch (DbUpdateException e)
            {
                ModelState.AddModelError("", _env.IsDevelopment() ? e.ToString() : _Common.Err_TryLater);
                Logger.LogError(e, e.ToString());
            }
            return RedirectToAction(nameof(Index));
        }
        #endregion


        public async Task<IActionResult> Details(Guid id)
        {
            if (id == null) return NotFound();
            var target = await UserManager.Users.FirstOrDefaultAsync(x => x.Id == id);
            if (target == null) return NotFound();

            ViewBag.Title = _Common.Details;
            var model = Mapper.Map<AppUser, UserDto>(target);
            return View(model);
        }

        private async Task InitViewBags(UserDto vm = null)
        {
            ViewBag.UserEmail = vm?.Email;
            ViewBag.UserDisplayName = $"{vm?.FirstName} {vm?.LastName}";
            //ViewBag.AgentId = await UserManager.GetSelectList(AppRoleName.Agent, vm?.AgentId);
            //ViewBag.Role = SelectListServiceExtensions.GetMemberRolesSelectList(vm?.Role);
            await Task.CompletedTask;
        }
        private async Task InitViewBags(RegisterVm vm = null)
        {
            //ViewBag.AgentId = await UserManager.GetSelectList(AppRoleName.Agent, vm?.AgentId);
            await Task.CompletedTask;
        }

        public async Task<IActionResult> ResetPassword(string id)
        {
            if (id == null) return NotFound();
            var target = await UserManager.FindByIdAsync(id);
            if (target == null) return NotFound();
            ViewBag.UserEmail = target.Email;
            ViewBag.UserDisplayName = target.FirstName + " " + target.LastName;
            var model = new ForceResetPasswordVm()
            {
                DisplayName = target.FirstName + " " + target.LastName,
                Email = target.Email
            };
            return View(model);
        }
        [HttpPost]
        public async Task<IActionResult> ResetPassword(ForceResetPasswordVm vm)
        {
            if (ModelState.IsValid)
            {
                try
                {
                    var target = await UserManager.FindByEmailAsync(vm.Email);
                    await UserManager.RemovePasswordAsync(target);
                    await UserManager.AddPasswordAsync(target, vm.NewPassword);
                    //await UserManager.UpdateSecurityStampAsync(target);
                    //await _signInManager.RefreshSignInAsync(target);
                    Logger.LogInformation("Password reset for User {0}", vm.Email);
                    return RedirectToAction("Index", "Users", new { area = "Admin" });
                }
                catch (Exception e)
                {
                    ModelState.AddModelError("", _env.IsDevelopment() ? e.ToString() : _Common.Err_TryLater);
                    Logger.LogError(e, e.ToString());
                }
            }
            return View(vm);
        }

        #region Disable
        [HttpGet]
        public async Task<IActionResult> Disable(string id)
        {
            try
            {
                var target = await UserManager.Users.FirstOrDefaultAsync(x => x.Id == new Guid(id));
                target.IsActive = false;
                await UserManager.UpdateAsync(target);
                Logger.LogInformation("Disabled {0} #{1}", nameof(Index), id);
            }
            catch (DbUpdateException e)
            {
                ModelState.AddModelError("", _env.IsDevelopment() ? e.ToString() : _Common.Err_TryLater);
                Logger.LogError(e, e.ToString());
            }
            return RedirectToAction(nameof(Index));
        }
        #endregion

        #region Enable
        [HttpGet]
        public async Task<IActionResult> Enable(string id)
        {
            try
            {
                var target = await UserManager.Users.FirstOrDefaultAsync(x => x.Id == new Guid(id));
                target.IsActive = true;
                await UserManager.UpdateAsync(target);
                Logger.LogInformation("Enabled {0} #{1}", nameof(Index), id);
            }
            catch (DbUpdateException e)
            {
                ModelState.AddModelError("", _env.IsDevelopment() ? e.ToString() : _Common.Err_TryLater);
                Logger.LogError(e, e.ToString());
            }
            return RedirectToAction(nameof(Index));
        }
        #endregion

        public async Task<IActionResult> Search(string q = "")
        {
            try
            {
                var empty = string.IsNullOrEmpty(q?.Trim().ToLower());
                var result = new Select2List
                {
                    results = await UserManager.Users
                                               .Where(x => x.DeletionDate == null)
                                               .Where(x => (empty || x.FullName.ToLower().Contains(q)))
                                               .Select(x => new Select2ListItem { text = x.FullName + " (" + x.Email + ")", id = x.Id.ToString() })
                                               .Take(6)
                                               .ToArrayAsync()
                };

                return Json(result);
            }
            catch (Exception e)
            {
                return Json(new Select2List { results = new[] { new Select2ListItem { text = e.ToString(), id = "" } } });
            }
        }
    }
}
