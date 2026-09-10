using App.Extensions;
using App.Resources;
using AutoMapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using System;
using System.Linq;
using System.Threading.Tasks;
using URF.Core.Abstractions;
using App.Models.ManageViewModels;
using Solf.Services;
using App.Shared.Entities;

namespace App.Controllers
{
    [Authorize]
    public class MeController : BaseController
    {
        private readonly IEmailService _emailService;
        private readonly IWebHostEnvironment _env;
        private readonly SignInManager<AppUser> _signInManager;

        public MeController(IUnitOfWork UOW,
                                    ILogger<MeController> logger,
                                    UserManager<AppUser> userManager,
                                    SignInManager<AppUser> signInManager,
                                    IMapper mapper,
                                    IEmailService emailService,
                                    IWebHostEnvironment env) : base(UOW, mapper, logger, userManager)
        {
            _emailService = emailService;
            _env = env;
            _signInManager = signInManager;
        }

        #region Index

        public async Task<IActionResult> Index()
        {
            if (!User.Identity.IsAuthenticated) return RedirectToAction("Index", "Home", new { area = "" });

            var uid = User.GetUserId();
            var user = await UserManager.Users
                                        .FirstOrDefaultAsync(x => x.Id == uid);
            var model = Mapper.Map<UserDto>(user);

            ViewBag.Title = _Account.Profile;
            return View(model);
        }
        #endregion

        #region Edit
        public async Task<IActionResult> Edit()
        {
            if (!User.Identity.IsAuthenticated) return RedirectToAction("Index", "Home", new { area = "" });

            var uid = User.GetUserId();
            var user = await UserManager.Users.FirstOrDefaultAsync(x => x.Id == uid);
            var model = Mapper.Map<UserDto>(user);
            ViewBag.Title = _Account.Profile + " - " + _Common.Edit;
            return View(model);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Edit(UserDto vm)
        {
            var target = await UserManager.GetUserAsync(User);
            if (target == null) return NotFound();

            if (ModelState.IsValid)
            {
                try
                {
                    var oldEmail = target.Email;

                    target.FirstName = vm.FirstName;
                    target.LastName = vm.LastName;
                    target.FullName = $"{vm.FirstName} {vm.LastName}";
                    target.Gender = vm.Gender;
                    target.PhoneNumber = vm.PhoneNumber;

                    var result = await UserManager.UpdateAsync(target);

                    if (!result.Succeeded) return RedirectToAction(nameof(Index));

                    Logger.LogInformation("Edit User {0}", target.Email);

                    if (vm.Email != oldEmail)
                    {
                        await UserManager.SendEmailChangeConfirmationEmail(_emailService, target, vm.Email);
                        SetToastr(_Account.ConfirmationEmailWasResent);
                    }
                    return RedirectToAction("Index", "Me", new { area = "" });

                }
                catch (DbUpdateConcurrencyException e)
                {
                    ModelState.AddModelError("", _env.IsDevelopment() ? e.ToString() : _Common.Err_TryLater);
                    Logger.LogError(e, e.ToString());
                }
                catch (Exception e)
                {
                    ModelState.AddModelError("", _env.IsDevelopment() ? e.ToString() : _Common.Err_TryLater);
                    Logger.LogError(e, e.ToString());
                }
            }
            ViewBag.Title = _Account.Profile + " - " + _Common.Edit;
            return View(vm);
        }
        #endregion

        #region ChangePassword
        [HttpGet]
        public async Task<IActionResult> ChangePassword()
        {
            var user = await UserManager.GetUserAsync(User);
            if (user == null) throw new ApplicationException($"Unable to load user with ID '{UserManager.GetUserId(User)}'.");

            var hasPassword = await UserManager.HasPasswordAsync(user);
            if (!hasPassword) return RedirectToAction(nameof(SetPassword));
            var model = Mapper.Map<UserDto>(user);
            return View(model);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> ChangePassword(ChangePasswordViewModel model)
        {
            var user = await UserManager.Users.FirstOrDefaultAsync(x => x.Id == User.GetUserId());
            if (user == null) throw new ApplicationException($"Unable to load user with ID '{UserManager.GetUserId(User)}'.");
            if (!ModelState.IsValid) return View(Mapper.Map<UserDto>(user));

            var res = await UserManager.ChangePasswordAsync(user, model.OldPassword, model.NewPassword);
            if (!res.Succeeded)
            {
                ModelState.AddModelError("", string.Join(",", res.Errors.Select(x => x.Description).ToArray()));
                return View();
            }

            await _signInManager.SignInAsync(user, isPersistent: false);

            Logger.LogInformation("User changed their password successfully.");
            SetToastr("Your password has been changed.");

            return RedirectToAction(nameof(Index));
        }
        #endregion

        #region SetPassword
        [HttpGet]
        public async Task<IActionResult> SetPassword()
        {
            var user = await UserManager.Users.FirstOrDefaultAsync(x => x.Id == User.GetUserId());
            if (user == null) throw new ApplicationException($"Unable to load user with ID '{UserManager.GetUserId(User)}'.");

            var hasPassword = await UserManager.HasPasswordAsync(user);
            if (hasPassword) return RedirectToAction(nameof(ChangePassword));
            var model = Mapper.Map<UserDto>(user);
            return View(model);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> SetPassword(SetPasswordVm model)
        {
            if (!ModelState.IsValid) return View(model);
            var user = await UserManager.Users.FirstOrDefaultAsync(x => x.Id == User.GetUserId());
            if (user == null) throw new ApplicationException($"Unable to load user with ID '{UserManager.GetUserId(User)}'.");

            var res = await UserManager.AddPasswordAsync(user, model.NewPassword);
            if (!res.Succeeded)
            {
                ModelState.AddModelError("", string.Join(",", res.Errors.Select(x => x.Description).ToArray()));
                return View(Mapper.Map<UserDto>(user));
            }

            await _signInManager.SignInAsync(user, isPersistent: false);
            SetToastr(_Account.YourPasswordHasBeenSet);
            //SetToastr("Your password has been set.");

            return RedirectToAction(nameof(Index));
        }

        #endregion

    }
}
