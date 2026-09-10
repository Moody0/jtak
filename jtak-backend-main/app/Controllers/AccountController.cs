using System;
using System.Security.Claims;
using System.Threading.Tasks;
using AutoMapper;
using App.Extensions;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using App.Models.AccountViewModels;
using Microsoft.Extensions.Localization;
using Solf.Services;
using URF.Core.Abstractions;
using App.Shared.Entities;
using App.Shared.Entities.Resources;
using App.Shared.Entities.Enums;
using App.Shared.Services.Extentions;

namespace App.Controllers
{
    [Authorize]
    public class AccountController : BaseController
    {
        private readonly SignInManager<AppUser> _signInManager;
        private readonly IEmailService _emailService;
        private readonly IStringLocalizer<AccountController> _localizer;
        private readonly IWebHostEnvironment _env;

        public AccountController(IUnitOfWork unitOfWork,
            IMapper mapper,
            SignInManager<AppUser> signInManager,
            ILogger<AccountController> logger,
            IWebHostEnvironment env,
            UserManager<AppUser> userManager,
            IStringLocalizer<AccountController> localizer,
            IEmailService emailService) : base(unitOfWork, mapper, logger, userManager)
        {
            _signInManager = signInManager;
            _localizer = localizer;
            _emailService = emailService;
            _env = env;
        }

        [HttpGet]
        [AllowAnonymous]
        public async Task<IActionResult> Login(string ReturnUrl = null)
        {
            //if (User.Identity.IsAuthenticated) return RedirectToLocal(ReturnUrl);

            // Clear the existing external cookie to ensure a clean login process
            await HttpContext.SignOutAsync(IdentityConstants.ExternalScheme);

            ViewBag.ReturnUrl = ReturnUrl;
            ViewBag.Title = _localizer["Login"];
            return View();
        }

        [HttpPost]
        [AllowAnonymous]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Login(LoginViewModel model, string ReturnUrl)
        {
            ViewBag.RedirectUrl = ReturnUrl;
            if (ModelState.IsValid)
            {
                // This doesn't count login failures towards account lockout
                // To enable password failures to trigger account lockout, set lockoutOnFailure: true
                var user = await UserManager.FindByEmailAsync(model.Email);
                if (user == null || user.DeletionDate != null)
                {
                    ModelState.AddModelError(string.Empty, "Invalid login attempt.");
                    return View(model);
                }
                var result = await _signInManager.PasswordSignInAsync(model.Email, model.Password, model.RememberMe, lockoutOnFailure: false);

                if (result.Succeeded)
                {
                    user.LastLoginDate = DateTime.UtcNow;
                    await UserManager.UpdateAsync(user);

                    var isUser = await UserManager.IsInRoleAsync(user, nameof(AppRoleName.Customer));

                    Logger.LogInformation("User logged in.");
                    return RedirectToLocal(ReturnUrl);
                }
                if (result.RequiresTwoFactor)
                {
                    return RedirectToAction(nameof(LoginWith2fa), new { ReturnUrl, model.RememberMe });
                }
                if (result.IsLockedOut)
                {
                    Logger.LogWarning("User account locked out.");
                    return RedirectToAction(nameof(Lockout));
                }
                else
                {
                    ModelState.AddModelError(string.Empty, "Invalid login attempt.");
                    return View(model);
                }
            }

            // If we got this far, something failed, redisplay form
            return View(model);
        }

        [HttpGet]
        [AllowAnonymous]
        public async Task<IActionResult> LoginWith2fa(bool rememberMe, string returnUrl = null)
        {
            // Ensure the user has gone through the username & password screen first
            var user = await _signInManager.GetTwoFactorAuthenticationUserAsync();

            if (user == null)
            {
                throw new ApplicationException($"Unable to load two-factor authentication user.");
            }

            var model = new LoginWith2faViewModel { RememberMe = rememberMe };
            ViewData["ReturnUrl"] = returnUrl;

            return View(model);
        }

        [HttpPost]
        [AllowAnonymous]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> LoginWith2fa(LoginWith2faViewModel model, bool rememberMe, string returnUrl = null)
        {
            if (!ModelState.IsValid)
            {
                return View(model);
            }

            var user = await _signInManager.GetTwoFactorAuthenticationUserAsync();
            if (user == null)
            {
                throw new ApplicationException($"Unable to load user with ID '{UserManager.GetUserId(User)}'.");
            }

            var authenticatorCode = model.TwoFactorCode.Replace(" ", string.Empty).Replace("-", string.Empty);

            var result = await _signInManager.TwoFactorAuthenticatorSignInAsync(authenticatorCode, rememberMe, model.RememberMachine);

            if (result.Succeeded)
            {
                Logger.LogInformation("User with ID {0} logged in with 2fa.", user.Id);
                return RedirectToLocal(returnUrl);
            }
            else if (result.IsLockedOut)
            {
                Logger.LogWarning("User with ID {0} account locked out.", user.Id);
                return RedirectToAction(nameof(Lockout));
            }
            else
            {
                Logger.LogWarning("Invalid authenticator code entered for user with ID {0}.", user.Id);
                ModelState.AddModelError(string.Empty, "Invalid authenticator code.");
                return View();
            }
        }

        [HttpGet]
        [AllowAnonymous]
        public async Task<IActionResult> LoginWithRecoveryCode(string returnUrl = null)
        {
            // Ensure the user has gone through the username & password screen first
            var user = await _signInManager.GetTwoFactorAuthenticationUserAsync();
            if (user == null)
            {
                throw new ApplicationException($"Unable to load two-factor authentication user.");
            }

            ViewData["ReturnUrl"] = returnUrl;

            return View();
        }

        [HttpPost]
        [AllowAnonymous]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> LoginWithRecoveryCode(LoginWithRecoveryCodeViewModel model, string returnUrl = null)
        {
            if (!ModelState.IsValid)
            {
                return View(model);
            }

            var user = await _signInManager.GetTwoFactorAuthenticationUserAsync();
            if (user == null)
            {
                throw new ApplicationException($"Unable to load two-factor authentication user.");
            }

            var recoveryCode = model.RecoveryCode.Replace(" ", string.Empty);

            var result = await _signInManager.TwoFactorRecoveryCodeSignInAsync(recoveryCode);

            if (result.Succeeded)
            {
                Logger.LogInformation("User with ID {UserId} logged in with a recovery code.", user.Id);
                return RedirectToLocal(returnUrl);
            }
            if (result.IsLockedOut)
            {
                Logger.LogWarning("User with ID {UserId} account locked out.", user.Id);
                return RedirectToAction(nameof(Lockout));
            }
            else
            {
                Logger.LogWarning("Invalid recovery code entered for user with ID {UserId}", user.Id);
                ModelState.AddModelError(string.Empty, "Invalid recovery code entered.");
                return View();
            }
        }

        [HttpGet]
        [AllowAnonymous]
        public IActionResult Lockout()
        {
            return View();
        }

        [HttpGet]
        [AllowAnonymous]
        public IActionResult Delete()
        {
            return Ok();
        }

        [HttpGet]

        [AllowAnonymous]
        public IActionResult Register(string ReturnUrl = null)
        {
            ViewData["ReturnUrl"] = ReturnUrl;
            return View();
        }

        [HttpPost]
        [AllowAnonymous]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Register(RegisterVm model, string ReturnUrl = null)
        {
            ViewData["ReturnUrl"] = ReturnUrl;
            if (ModelState.IsValid)
            {
                var user = new AppUser
                {
                    UserName = model.Email,
                    Email = model.Email,
                    FirstName = model.FirstName,
                    LastName = model.LastName,
                    FullName = $"{model.FirstName} {model.LastName}",
                    Gender = model.Gender,
                    ProfilePhoto = model.Gender == Gender.Male ? "male.jpg" : "female.jpg"
                };
                var result = await UserManager.CreateAsync(user, model.Password);
                if (result.Succeeded)
                {
                    Logger.LogInformation("User created a new account with password.");

                    await UserManager.SendEmailConfirmationEmail(_emailService, user);

                    result = await UserManager.AddToRoleAsync(user, AppRoleName.Customer.ToString());

                    await _signInManager.SignInAsync(user, isPersistent: false);
                    Logger.LogInformation("User created a new account with password.");
                    return RedirectToLocal(ReturnUrl);
                }
                AddErrors(result);
            }

            // If we got this far, something failed, redisplay form
            return View(model);
        }

        //[HttpPost]
        //[ValidateAntiForgeryToken]
        [AllowAnonymous]
        public async Task<IActionResult> Logout(string ReturnUrl = null)
        {
            HttpContext.Session.Clear();
            CurrentUser = null;
            await _signInManager.SignOutAsync();
            Logger.LogInformation("User logged out.");
            return RedirectToLocal(ReturnUrl);
        }

        [HttpPost]
        [AllowAnonymous]
        [ValidateAntiForgeryToken]
        public IActionResult ExternalLogin(string provider, string ReturnUrl = null)
        {
            // Request a redirect to the external login provider.
            var returnUrl = provider == "Google2" ? Url.Action(nameof(AddGoogleLoginCallback), "Account", new { ReturnUrl }, "https") : Url.Action(nameof(ExternalLoginCallback), "Account", new { ReturnUrl }, "https");
            var properties = _signInManager.ConfigureExternalAuthenticationProperties(provider, returnUrl);
            return Challenge(properties, provider);
        }

        [HttpGet]
        public async Task<IActionResult> AddGoogleLoginCallback(string returnUrl = null, string remoteError = null)
        {
            if (remoteError != null)
            {
                SetToastr("Error from external provider", "error");
                return RedirectToAction(nameof(Login));
            }

            var info = await _signInManager.GetExternalLoginInfoAsync();
            if (info == null)
            {
                return RedirectToAction(nameof(Login));
            }
            // Update current user access token
            var user = await UserManager.GetUserAsync(User);
            user.ExternalUserId = info.Principal.FindFirstValue(ClaimTypes.NameIdentifier);
            user.ExternalTokenResponse = info.Principal.FindFirstValue("ExternalTokenResponse");
            await UserManager.UpdateAsync(user);

            return returnUrl != null ? RedirectToLocal(returnUrl) : RedirectToAction("Index", "Courses", new { area = "Content" });
        }


        [HttpGet]
        [AllowAnonymous]
        public async Task<IActionResult> ExternalLoginCallback(string returnUrl = null, string remoteError = null)
        {
            if (remoteError != null)
            {
                SetToastr("Error from external provider", "error");
                return RedirectToAction(nameof(Login));
            }

            var info = await _signInManager.GetExternalLoginInfoAsync();
            if (info == null) return RedirectToAction(nameof(Login));

            try
            {
                var user = await UserManager.CreateOrLinkLogin(_env,
                                                                info.LoginProvider,
                                                                info.ProviderKey,
                                                                info.Principal.GetUserEmail(),
                                                                info.Principal.GetUserName(),
                                                                null,
                                                                info.Principal.GetUserPicture());
                var result = await _signInManager.ExternalLoginSignInAsync(info.LoginProvider, info.ProviderKey, isPersistent: false, bypassTwoFactor: true);
                if (result.Succeeded)
                {
                    CurrentUser = Mapper.Map<AppUser, UserDto>(user);
                    Logger.LogInformation("User logged in with {0} provider.", info.LoginProvider);

                    user.LastLoginDate = DateTime.UtcNow;
                    await UserManager.UpdateAsync(user);

                    var isUser = await UserManager.IsInRoleAsync(user, nameof(AppRoleName.Customer));

                    Logger.LogInformation("User logged in.");
                    return RedirectToLocal(returnUrl);
                }
            }

            catch (Exception ex) { SetToastr(ex.Message, "error"); }
            // SignInResult Error
            SetToastr(_Errors.ErrorTryLater, "error");
            ViewData["ReturnUrl"] = returnUrl;
            return View(nameof(Login));
        }

        [HttpPost]
        [AllowAnonymous]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> ExternalLoginConfirmation(ExternalLoginViewModel model, string returnUrl = null)
        {
            if (ModelState.IsValid)
            {
                // Get the information about the user from the external login provider
                var info = await _signInManager.GetExternalLoginInfoAsync();
                if (info == null)
                {
                    throw new ApplicationException("Error loading external login information during confirmation.");
                }
                var user = new AppUser { UserName = model.Email, Email = model.Email };
                var result = await UserManager.CreateAsync(user);
                if (result.Succeeded)
                {
                    result = await UserManager.AddLoginAsync(user, info);
                    if (result.Succeeded)
                    {
                        await _signInManager.SignInAsync(user, isPersistent: false);
                        Logger.LogInformation("User created an account using {DisplayName} provider.", info.LoginProvider);
                        return RedirectToLocal(returnUrl);
                    }
                }
                AddErrors(result);
            }

            ViewData["ReturnUrl"] = returnUrl;
            return View(nameof(ExternalLogin), model);
        }

        [HttpGet]
        [AllowAnonymous]
        public async Task<IActionResult> ConfirmEmail(string email, string code)
        {
            if (email == null || code == null) return RedirectToAction(nameof(Login));

            var user = await UserManager.FindByEmailAsync(email);
            if (user == null) throw new ApplicationException($"Unable to load user with userid '{email}'.");

            var result = await UserManager.ConfirmEmailAsync(user, code);
            if (!result.Succeeded)
            {
                await UserManager.SendEmailConfirmationEmail(_emailService, user);

                return View(false);
            }
            return View(true);
        }

        [HttpGet]
        [AllowAnonymous]
        public async Task<IActionResult> ConfirmChangeEmail(string userid, string newemail, string code)
        {
            if (newemail == null || code == null) return RedirectToAction(nameof(Login));

            var user = await UserManager.FindByIdAsync(userid);

            if (user == null) throw new ApplicationException($"Unable to load user with userid '{userid}'.");

            var result = await UserManager.ChangeEmailAsync(user, newemail, code);

            return View("ConfirmEmail", result.Succeeded);
        }

        [HttpGet]
        [AllowAnonymous]
        public async Task<IActionResult> ChangeEmail(string email, string newEmail, string code)
        {
            if (email == null || code == null) return RedirectToAction(nameof(Login));

            var user = await UserManager.FindByEmailAsync(email);
            if (user == null) throw new ApplicationException($"Unable to load user with email '{email}'.");

            var result = await UserManager.ChangeEmailAsync(user, newEmail, code);
            if (!result.Succeeded)
            {
                // If not success, resend confirmation email
                code = await UserManager.GenerateChangeEmailTokenAsync(user, newEmail);
                var callbackUrl = Url.EmailChangeLink(user.Id, newEmail, code);
                await _emailService.ReSendEmailChangeLinkAsync(user.FirstName, email, newEmail, callbackUrl);

                return View(false);
            }
            await _emailService.SendEmailChangedConfirmationAsync(user.FirstName, email, newEmail);
            return View(true);
        }

        [HttpGet]
        [AllowAnonymous]
        public IActionResult ForgotPassword()
        {
            return View();
        }

        [HttpPost]
        [AllowAnonymous]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> ForgotPassword(ForgotPasswordViewModel model)
        {
            if (ModelState.IsValid)
            {
                var user = await UserManager.FindByEmailAsync(model.Email);
                if (user == null || !(await UserManager.IsEmailConfirmedAsync(user)))
                {
                    // Don't reveal that the user does not exist or is not confirmed
                    return RedirectToAction(nameof(ForgotPasswordConfirmation));
                }

                // For more information on how to enable account confirmation and password reset please
                // visit https://go.microsoft.com/fwlink/?LinkID=532713
                await UserManager.SendPasswordResetEmail(_emailService, user);

                return RedirectToAction(nameof(ForgotPasswordConfirmation));
            }

            // If we got this far, something failed, redisplay form
            return View(model);
        }

        [HttpGet]
        [AllowAnonymous]
        public IActionResult ForgotPasswordConfirmation()
        {
            return View();
        }


        [HttpGet]
        [AllowAnonymous]
        public IActionResult ChoosePassword(string code = null)
        {
            if (code == null)
            {
                throw new ApplicationException("A code must be supplied for password reset.");
            }
            var model = new ResetPasswordVm { Code = code };
            return View(model);
        }

        [HttpPost]
        [AllowAnonymous]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> ChoosePassword(ResetPasswordVm model)
        {
            if (!ModelState.IsValid)
            {
                return View(model);
            }
            var user = await UserManager.FindByEmailAsync(model.Email);
            if (user == null)
            {
                // Don't reveal that the user does not exist
                return RedirectToAction(nameof(ResetPasswordConfirmation));
            }

            var result = await UserManager.ResetPasswordAsync(user, model.Code, model.Password);
            if (result.Succeeded)
            {
                var r = await _signInManager.PasswordSignInAsync(model.Email, model.Password, false, lockoutOnFailure: false);

                if (r.Succeeded)
                {
                    Logger.LogInformation("User logged in.");
                    return RedirectToLocal("/");
                }
            }
            AddErrors(result);
            return View();
        }

        [HttpGet]
        [AllowAnonymous]
        public IActionResult ResetPassword(string code = null, string email = null)
        {
            if (code == null)
            {
                throw new ApplicationException("A code must be supplied for password reset.");
            }
            var model = new ResetPasswordVm { Code = code, Email = email };
            return View(model);
        }

        [HttpPost]
        [AllowAnonymous]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> ResetPassword(ResetPasswordVm model)
        {
            if (!ModelState.IsValid) return View(model);

            var user = await UserManager.FindByEmailAsync(model.Email);
            if (user == null)
            {
                // Don't reveal that the user does not exist
                return RedirectToAction(nameof(ResetPasswordConfirmation));
            }
            var result = await UserManager.ResetPasswordAsync(user, model.Code, model.Password);
            if (result.Succeeded)
            {
                await _signInManager.SignInAsync(user, false);
                return RedirectToAction("Index", "Me");
            }
            AddErrors(result);
            return View();
        }

        [HttpGet]
        [AllowAnonymous]
        public IActionResult ResetPasswordConfirmation()
        {
            return View();
        }


        [HttpGet]
        public IActionResult AccessDenied()
        {
            return View();
        }

        #region Helpers

        private void AddErrors(IdentityResult result)
        {
            foreach (var error in result.Errors)
            {
                ModelState.AddModelError(string.Empty, error.Description);
            }
        }

        private IActionResult RedirectToLocal(string returnUrl)
        {
            if (string.IsNullOrWhiteSpace(returnUrl))
            {
                return RedirectToAction(nameof(HomeController.Index), "Home");
            }
            if (Url.IsLocalUrl(returnUrl))
            {
                return Redirect(returnUrl);
            }

            return RedirectToAction(nameof(HomeController.Index), "Home");
        }

        #endregion
    }
}
