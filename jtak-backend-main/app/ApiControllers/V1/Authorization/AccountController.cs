using System;
using System.Linq;
using System.Threading.Tasks;
using AutoMapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using App.ApiModels;
using App.Extensions;
using Microsoft.EntityFrameworkCore;
using App.Shared.Services;
using App.Resources;
using Solf.Extensions;
using OpenIddict.Validation.AspNetCore;
using Solf.Services;
using App.Shared.Data.App;
using App.Shared.Entities;
using App.Shared.Entities.Resources;
using App.Shared.Entities.Enums;
using System.Text.Json;
using Microsoft.Extensions.Logging;

namespace App.ApiControllers.V1.Authorization
{
    [Route("api/v{version:apiVersion}/Authorization/[controller]")]
    [ApiVersion("1")]
    public class AccountController : SolApiController
    {
        private readonly IMapper _mapper;
        private readonly IAppUnitOfWork _unitOfWork;
        private readonly UserManager<AppUser> _userManager;
        private readonly INotificationService _notificationService;
        private readonly IEmailService _emailService;
        private readonly ISmsLogService _smsLogService;
        private readonly ILogger _logger;

        public AccountController(IAppUnitOfWork unitOfWorkAsync,
            UserManager<AppUser> userManager,
            IMapper mapper,
            ILogger<AccountController> logger,
            ISmsLogService smsLogService,
            IEmailService emailService,
            INotificationService notificationService)
        {
            _unitOfWork = unitOfWorkAsync;
            _userManager = userManager;
            _mapper = mapper;
            _logger = logger;
            _smsLogService = smsLogService;
            _emailService = emailService;
            _notificationService = notificationService;
        }

        /// <summary>
        /// Update firebase token
        /// </summary>
        /// <param name="firebaseRegToken">updated firebase Reg Token for this user</param>
        /// <returns></returns>
        [HttpPost]
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        [Route("UpdateFirebaseToken/{firebaseRegToken}")]
        public async Task<ActionResult<bool>> UpdateFirebaseToken(string firebaseRegToken = null)
        {
            var uid = User.GetUserId();
            var user = await _userManager.Users.FirstOrDefaultAsync(x => x.Id == uid);

            if (!string.IsNullOrWhiteSpace(firebaseRegToken) && user != null)
            {
                user.DeviceId = firebaseRegToken;
                await _userManager.UpdateAsync(user);
            }

            return true;
        }

        /// <summary>
        /// Gets init information
        /// </summary>
        /// <param name="firebaseRegToken">updated firebase Reg Token for this user</param>
        /// <returns></returns>
        [HttpGet]
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        [AllowAnonymous]
        public async Task<ActionResult<InitData>> InitData(string firebaseRegToken = null)
        {
            var uid = User.GetUserId();
            var user = await _userManager.Users.FirstOrDefaultAsync(x => x.Id == uid);

            if (!string.IsNullOrWhiteSpace(firebaseRegToken) && user != null)
            {
                user.DeviceId = firebaseRegToken;
                await _userManager.UpdateAsync(user);
            }

            var u = user == null || user.DeletionDate != null || !user.IsActive ? null : _mapper.Map<UserDto>(user);

            if (u != null)
            {
                u.Role = (await _userManager.GetRoleNamesAsync(user))?.FirstOrDefault() ?? AppRoleName.Customer;
                u.HasPassword = await _userManager.HasPasswordAsync(user);
                u.UserTopicId = _notificationService.GetUserTopic(u.Id);
            }
            var model = new InitData
            {
                User = u
            };

            return model;
        }

        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme), HttpPost, Route("ChangePassword")]
        public async Task<ActionResult<string>> ChangePassword(ChangePasswordBindingModel model)
        {
            if (model?.OldPassword == null) return BadRequest(string.Format(_Errors.FieldIsRequired, model.OldPassword.ToLocalizedName()));
            if (model?.NewPassword == null) return BadRequest(string.Format(_Errors.FieldIsRequired, model.NewPassword.ToLocalizedName()));
            if (model?.NewPassword.Length < 6) return BadRequest(string.Format(_Errors.BelowMinLength, model.NewPassword.ToLocalizedName(), 6));
            if (model?.ConfirmPassword == null) return BadRequest(string.Format(_Errors.FieldIsRequired, model.ConfirmPassword.ToLocalizedName()));

            if (model?.ConfirmPassword != model?.NewPassword) ApiErr.Create(_Errors.ConfirmPasswordNotMatch);

            var user = await _userManager.GetUserAsync(User);
            var result = await _userManager.ChangePasswordAsync(user, model.OldPassword, model.NewPassword);

            return !result.Succeeded ? BadRequest(result) : "OK";
        }

        /*
         * Route conflect with /ar/Account/ResetPassword
        [AllowAnonymous, HttpPost, Route("ResetPassword")]
        public async Task<ActionResult<string>> ResetPassword(ResetPasswordBindingModel model)
        {
            var user = await _userManager.FindByEmailAsync(model.Email);
            var result = await _userManager.ResetPasswordAsync(user, model.Code, model.NewPassword);

            user.EmailConfirmed = true;
            await _userManager.UpdateAsync(user);

            return !result.Succeeded ? ApiResponse<string>.CreateFailure(result) : ApiResponse<string>.Create("OK");
        }
        */

        [AllowAnonymous, HttpPost, Route("Confirm")]
        public async Task<ActionResult<string>> Confirm(ConfirmEmailBindingModel model)
        {
            if (model?.Email == null || model?.Code == null) return BadRequest("Email or Code invalid");

            var user = await _userManager.FindByEmailAsync(model.Email);
            if (user == null) return BadRequest("Invalid or Expired code, a new code was sent");

            var result = await _userManager.ConfirmEmailAsync(user, model.Code);
            if (!result.Succeeded)
            {
                // resend the email
                await _userManager.SendEmailConfirmationEmail(_emailService, user);

                return BadRequest("Invalid or Expired code, a new code was sent");
            }
            return "Ok";
        }

        [AllowAnonymous, HttpPost, Route("ChangeEmail")]
        public async Task<ActionResult<string>> ChangeEmail(ChangeEmailBindingModel model)
        {
            if (model?.Email == null || model?.Code == null) return BadRequest("Email or Code invalid");

            var user = await _userManager.FindByEmailAsync(model.Email);
            if (user == null) return BadRequest($"Unable to load user with email '{model.Email}'.");

            var result = await _userManager.ChangeEmailAsync(user, model.NewEmail, model.Code);
            if (!result.Succeeded)
            {
                // resend the email
                //await _userManager.SendEmailChangeConfirmationEmail(_notificationService, user);

                return BadRequest("Invalid or Expired code, a new code was sent");
            }
            return "Ok";
        }

        /// <summary>
        /// Set user password, if there is no old password
        /// </summary>
        /// <param name="model">SetPasswordBindingModel</param>
        /// <returns>ApiResponse&lt;string&gt;</returns>
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme), HttpPost, Route("SetPassword")]
        public async Task<ActionResult<string>> SetPassword(SetPasswordBindingModel model)
        {
            var user = await _userManager.GetUserAsync(User);
            /*
            // Remove old password
            if (!await _userManager.HasPasswordAsync(user))
            {
                var r = await _userManager.RemovePasswordAsync(user);
                if (!r.Succeeded) ApiResponse<string>.CreateFailure(r);
            }
            */
            // Add new password
            var result = await _userManager.AddPasswordAsync(user, model.NewPassword);

            return !result.Succeeded ? BadRequest(result) : "OK";
        }

        /// <summary>
        /// Register new user
        /// </summary>
        /// <param name="model">RegisterBindingModel</param>
        /// <returns>ApiResponse&lt;string&gt;</returns>
        [AllowAnonymous]
        [HttpPost]
        public async Task<ActionResult<string>> Create(RegisterBindingModel model)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);

            var user = new AppUser
            {
                UserName = model.Email,
                Email = model.Email,
                PhoneNumber = model.PhoneNumber,
                CountryPhoneCode = model.CountryPhoneCode,
                FullName = model.FullName,
                Gender = model.Gender,
                Birthday = model.Birthday,
                DeviceId = model.DeviceId
            };

            var result = await _userManager.CreateAsync(user, model.Password);
            if (!result.Succeeded)
                return BadRequest(result);

            result = await _userManager.AddToRoleAsync(user, nameof(AppRoleName.Customer));
            if (!result.Succeeded)
                return BadRequest(result);

            await _userManager.SendEmailConfirmationEmail(_emailService, user);

            if (user.PhoneNumber != null)
            {
                var code = await _userManager.GenerateChangePhoneNumberTokenAsync(user, model.PhoneNumber);
                var msg = string.Format(_Account.SmsVerification, code);
                try
                {
                    var response = await _notificationService.SendSmsNotification(model.PhoneNumber, msg);
                    _smsLogService.Insert(new SmsLog { UserId = user.Id, Code = code, Text = msg, Response = response });
                    await _unitOfWork.SaveChangesAsync();
                }
                catch (Exception) { }
            }

            return "OK";
        }

        /// <summary>
        /// Resend phone verification SMS Code to the specified number
        /// </summary>
        /// <param name="model">The phoneNumber with this Regex format ^\+?[1-9]\d{1,14}$ </param>
        /// <returns>Wait time for the next SMS in seconds</returns>
        [AllowAnonymous, HttpPost, Route("ResendSmsCode")]
        public async Task<ActionResult<int>> ResendSmsCode(PhoneNumberModel model)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);

            var user = await _userManager.FindByNameAsync(model.PhoneNumber);
            //var waitTimeInSecs = await _smsLogService.GetSMSResendWaitTime(user?.Id);
            var waitTimeInSecs = 0;
            var hasDisplayName = user?.FirstName != null && user?.LastName != null;

            if (waitTimeInSecs > 0)
                return BadRequest($"You need to wait {waitTimeInSecs}s");

            var code = await _userManager.GenerateChangePhoneNumberTokenAsync(user, model.PhoneNumber);
            var msg = string.Format(_Account.SmsVerification, code);
            var response = await _notificationService.SendSmsNotification(model.PhoneNumber, msg);
            _smsLogService.Insert(new SmsLog { UserId = user.Id, Code = code, Text = msg/*, Response = response */});

            await _unitOfWork.SaveChangesAsync();

            return waitTimeInSecs;
        }

        /// <summary>
        /// Resend phone verification SMS Code to the specified number
        /// </summary>
        /// <param name="model">The phoneNumber with this Regex format ^\+?[1-9]\d{1,14}$ </param>
        /// <returns>Has display name or not</returns>
        [AllowAnonymous, HttpPost, Route("RegisterOrSignInByPhoneNumber")]
        public async Task<ActionResult<string>> RegisterOrSignInByPhoneNumber(PhoneNumberModel model)
        {
            var user = await _userManager.Users.FirstOrDefaultAsync(x => x.UserName == model.PhoneNumber) ?? await _userManager.Users.FirstOrDefaultAsync(x => x.PhoneNumber == model.PhoneNumber);

            if (user == null)
            {
                user = new AppUser { UserName = model.PhoneNumber, PhoneNumber = model.PhoneNumber, IsActive = true };

                var result = await _userManager.CreateAsync(user);
                if (!result.Succeeded)
                {
                    _logger.LogError($"Couldn't create user account on order submit: {JsonSerializer.Serialize(user)}");
                    return BadRequest(result);
                }

                result = await _userManager.AddToRoleAsync(user, AppRoleName.Customer.ToString());
                if (!result.Succeeded)
                {
                    _logger.LogError($"Couldn't add user to role on order submit: {JsonSerializer.Serialize(user)}");
                    return BadRequest(result);
                }
                user = await _userManager.FindByPhoneNumberAsync(model.PhoneNumber);
            }
            //var waitTimeInSecs = await _smsLogService.GetSMSResendWaitTime(user?.Id);
            var waitTimeInSecs = 0;

            var hasDisplayName = user?.FirstName != null && user?.LastName != null;

            if (waitTimeInSecs > 0)
                return BadRequest($"You need to wait {waitTimeInSecs}s");

            var code = await _userManager.GenerateChangePhoneNumberTokenAsync(user, model.PhoneNumber);
            var msg = string.Format(_Account.SmsVerification, code);

            var response = await _notificationService.SendSmsNotification(model.PhoneNumber, msg);
            _smsLogService.Insert(new SmsLog { UserId = user.Id, Code = code, Text = msg, Response = response });

            await _unitOfWork.SaveChangesAsync();

#if DEBUG
            return code;
#else
            return string.Empty;
#endif
        }

        /// <summary>
        /// Sends verification SMS Code strictly to registered and active Merchant accounts.
        /// Unregistered numbers or non-merchant accounts are rejected without sending an SMS.
        /// </summary>
        /// <param name="model">The phoneNumber with this Regex format ^\+?[1-9]\d{1,14}$ </param>
        /// <returns>Debug verification code or empty string</returns>
        [AllowAnonymous, HttpPost, Route("MerchantSignInByPhoneNumber")]
        public async Task<ActionResult<string>> MerchantSignInByPhoneNumber(PhoneNumberModel model)
        {
            var user = await _userManager.Users.FirstOrDefaultAsync(x => x.UserName == model.PhoneNumber)
                    ?? await _userManager.Users.FirstOrDefaultAsync(x => x.PhoneNumber == model.PhoneNumber);

            // 1. Verify user exists and has the Merchant role
            if (user == null || !await _userManager.IsInRoleAsync(user, AppRoleName.Merchant.ToString()))
            {
                return StatusCode(403, new
                {
                    error = "MERCHANT_NOT_FOUND",
                    errorDescription = "هذا الرقم غير مسجل كتاجر معتمد في جيتك. يرجى التواصل مع إدارة العمليات لتفعيل متجرك."
                });
            }

            // 2. Verify merchant account is active
            if (!user.IsActive)
            {
                return StatusCode(403, new
                {
                    error = "MERCHANT_SUSPENDED",
                    errorDescription = "حساب التاجر موقوف حالياً. يرجى مراجعة إدارة جيتك."
                });
            }

            var waitTimeInSecs = 0;
            if (waitTimeInSecs > 0)
                return BadRequest($"You need to wait {waitTimeInSecs}s");

            var code = await _userManager.GenerateChangePhoneNumberTokenAsync(user, model.PhoneNumber);
            var msg = string.Format(_Account.SmsVerification, code);

            var response = await _notificationService.SendSmsNotification(model.PhoneNumber, msg);
            _smsLogService.Insert(new SmsLog { UserId = user.Id, Code = code, Text = msg, Response = response });

            await _unitOfWork.SaveChangesAsync();

#if DEBUG
            return code;
#else
            return string.Empty;
#endif
        }

        /// <summary>
        /// Verifies user phoneNumber after reciving SMS code
        /// </summary>
        /// <param name="model">VerifyPhoneNumber</param>
        /// <returns></returns>
        [AllowAnonymous, HttpPost, Route("VerifyPhoneNumber")]
        public async Task<ActionResult<string>> VerifyPhoneNumber(VerifyPhoneNumberVm model)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);

            var user = await _userManager.FindByNameAsync(model?.PhoneNumber);
            var result = await _userManager.ChangePhoneNumberAsync(user, model?.PhoneNumber, model?.Code);

            return result.Succeeded ? "OK" : BadRequest(_Errors.InvalidCode);
        }

        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme), HttpPost, Route("SetLang")]
        public async Task<ActionResult<string>> SetLang(string lang)
        {
            var user = await _userManager.GetUserAsync(User);
            user.Lang = lang;
            await _userManager.UpdateAsync(user);
            return "OK";
        }


        /// <summary>
        /// Update currently logged in user User information
        /// if phone number was changed, an sms will be sent to the new number
        /// The client should call '/api/Account/VerifyPhoneNumber' end point to confirm/save the PhoneNumber update
        /// </summary>
        /// <returns>ApiResponse&lt;string&gt;</returns>
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme), HttpPost, Route("UpdateUser")]
        public async Task<ActionResult<string>> UpdateUserProfile(UserUpdateVm vm)
        {
            var user = await _userManager.GetUserAsync(User)
                ?? (User.GetUserId() != null ? await _userManager.FindByIdAsync(User.GetUserId().ToString()) : null);

            if (user == null && !string.IsNullOrWhiteSpace(vm.PhoneNumber))
            {
                user = await _userManager.FindByPhoneNumberAsync(vm.PhoneNumber)
                    ?? await _userManager.FindByNameAsync(vm.PhoneNumber);
            }

            if (user == null)
                return Unauthorized();

            if (!string.IsNullOrWhiteSpace(vm.FullName))
            {
                user.FullName = vm.FullName.Trim();
                user.FirstName = user.FullName.Split(' ').FirstOrDefault() ?? user.FullName;
                user.LastName = user.FullName.Contains(' ') ? user.FullName.Substring(user.FirstName.Length).Trim() : "";
            }

            if (!string.IsNullOrWhiteSpace(vm.ProfilePhoto))
                user.ProfilePhoto = vm.ProfilePhoto;

            if (!string.IsNullOrWhiteSpace(vm.PhoneNumber))
                user.PhoneNumber = vm.PhoneNumber;

            if (!string.IsNullOrWhiteSpace(vm.CountryPhoneCode))
                user.CountryPhoneCode = vm.CountryPhoneCode;

            if (vm.Gender.HasValue)
                user.Gender = vm.Gender;

            if (vm.Birthday.HasValue)
                user.Birthday = vm.Birthday;

            if (!string.IsNullOrWhiteSpace(vm.Email) && user.Email != vm.Email)
            {
                try
                {
                    await _userManager.SendEmailChangeConfirmationEmail(_emailService, user, vm.Email);
                }
                catch (Exception ex)
                {
                    _logger.LogWarning($"Email change confirmation failed: {ex.Message}");
                }
                user.Email = vm.Email;
            }

            var result = await _userManager.UpdateAsync(user);
            if (!result.Succeeded) return BadRequest(result);
            await _unitOfWork.SaveChangesAsync();
            return "OK";
        }


        /*

        /// <summary>
        /// Update currently logged in user User information
        /// if phone number was changed, an sms will be sent to the new number
        /// The client should call '/api/Account/ResetPassword' to reset the password
        /// </summary>
        /// <returns>ApiResponse&lt;string&gt;</returns>
        [AllowAnonymous, HttpPost, Route("ForgetPassword")]
        public async Task<ActionResult<string>> ForgetPassword(PhoneNumberModel model)
        {
            if (!ModelState.IsValid) return string>.CreateFailure(ModelState);

            var user = await _userManager.FindByNameAsync(model.PhoneNumber);

            var code = await _userManager.GeneratePasswordResetTokenAsync(user);
            var msg = string.Format(_Account.PasswordResetMessage, code);
            var response = await _notificationService.SendSmsNotification(model.PhoneNumber, msg);

            var lastDaySmsCount = _smsLogService.Queryable().Count(x => x.UserId == user.Id && (DateTime.Now - x.CreatedDate).TotalHours < 24);
            if (lastDaySmsCount > 3) return string>.CreateFailure("Please Try again in 24 hours");

            _smsLogService.Insert(new SmsLog { UserId = user.Id, Code = code, Text = msg, Response = response });

            await _unitOfWork.SaveChangesAsync();

            return string>.Create("OK");
        }

        */

        /// <summary>
        /// Send Password Reset Link to user email
        /// </summary>
        /// <returns>ApiResponse&lt;string&gt;</returns>
        [AllowAnonymous, HttpPost, Route("ForgetPassword")]
        public async Task<ActionResult<string>> ForgetPassword(EmailModel model)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var user = await _userManager.FindByEmailAsync(model.Email);
            if (user == null) return BadRequest(_Errors.NotFound);

            await _userManager.SendPasswordResetEmail(_emailService, user);

            return "OK";
        }

        //// POST api/Account/Logout
        //[Route("ConfirmEmail")]
        //public ActionResult ConfirmEmail(string userId, string code)
        //{
        //    if (userId == null || code == null)
        //    {
        //        return RedirectToAction(nameof(Login));
        //    }
        //    var user = await _userManager.FindByIdAsync(userId);
        //    if (user == null)
        //    {
        //        throw new ApplicationException($"Unable to load user with ID '{userId}'.");
        //    }
        //    var result = await _userManager.ConfirmEmailAsync(user, code);
        //    if (result.Succeeded)
        //    {
        //        var passwordResetCode = await _userManager.GeneratePasswordResetTokenAsync(user);
        //        return RedirectToAction("ChoosePassword", new { code = passwordResetCode });
        //    }
        //    return View("Error");
        //}

        // GET api/Account/ManageInfo?returnUrl=%2F&generateState=true
        //[ApiExplorerSettings(IgnoreApi = true)]
        //[Route("ManageInfo")]
        //public async Task<ManageInfoViewModel> GetManageInfo(string returnUrl, bool generateState = false)
        //{
        //    var user = await _userManager.GetUserAsync(User);

        //    if (user == null) return null;

        //    var logins = new List<UserLoginInfoViewModel>();

        //    foreach (var linkedAccount in user.Logins)
        //    {
        //        logins.Add(new UserLoginInfoViewModel
        //        {
        //            LoginProvider = linkedAccount.LoginProvider,
        //            ProviderKey = linkedAccount.ProviderKey
        //        });
        //    }

        //    if (user.PasswordHash != null)
        //    {
        //        logins.Add(new UserLoginInfoViewModel
        //        {
        //            LoginProvider = LocalLoginProvider,
        //            ProviderKey = user.UserName
        //        });
        //    }

        //    return new ManageInfoViewModel
        //    {
        //        LocalLoginProvider = LocalLoginProvider,
        //        Email = user.UserName,
        //        Logins = logins,
        //        ExternalLoginProviders = GetExternalLogins(returnUrl, generateState)
        //    };
        //}

        // POST api/Account/AddExternalLogin
        //[ApiExplorerSettings(IgnoreApi = true)]
        //[Route("AddExternalLogin")]
        //public async Task<ActionResult> AddExternalLogin(AddExternalLoginBindingModel model)
        //{
        //    if (!ModelState.IsValid)
        //    {
        //        return BadRequest(ModelState);
        //    }

        //    Authentication.SignOut(DefaultAuthenticationTypes.ExternalCookie);

        //    AuthenticationTicket ticket = AccessTokenFormat.Unprotect(model.ExternalAccessToken);

        //    if (ticket == null || ticket.Principal.Identity == null || (ticket.Properties != null
        //        && ticket.Properties.ExpiresUtc.HasValue
        //        && ticket.Properties.ExpiresUtc.Value < DateTimeOffset.UtcNow))
        //    {
        //        return BadRequest("External login failure.");
        //    }

        //    ExternalLoginData externalData = ExternalLoginData.FromIdentity(ticket.Principal.Identity);

        //    if (externalData == null)
        //    {
        //        return BadRequest("The external login is already associated with an account.");
        //    }

        //    var user = await _userManager.GetUserAsync(User);
        //    IdentityResult result = await _userManager.AddLoginAsync(user, new UserLoginInfo(externalData.LoginProvider, externalData.ProviderKey, user.DisplayName));

        //    if (!result.Succeeded)
        //    {
        //        return GetErrorResult(result);
        //    }

        //    return Ok();
        //}

        // POST api/Account/RemoveLogin
        //[ApiExplorerSettings(IgnoreApi = true)]
        //[Route("RemoveLogin")]
        //public async Task<ActionResult> RemoveLogin(RemoveLoginBindingModel model)
        //{
        //    if (!ModelState.IsValid)
        //    {
        //        return BadRequest(ModelState);
        //    }

        //    IdentityResult result;

        //    var user = await _userManager.GetUserAsync(User);
        //    if (model.LoginProvider == LocalLoginProvider)
        //    {
        //        result = await _userManager.RemovePasswordAsync(user);
        //    }
        //    else
        //    {
        //        result = await _userManager.RemoveLoginAsync(user, model.LoginProvider, model.ProviderKey);
        //    }

        //    if (!result.Succeeded)
        //    {
        //        return GetErrorResult(result);
        //    }

        //    return Ok();
        //}


        // GET api/Account/ExternalLogin
        ///// <summary>
        ///// External login end-point, it does the followong:
        ///// - redirect you to the appropriate External provider
        ///// - provide your credentials (if not already logged in on the external provider)
        ///// - User consent for the app 
        ///// - Retrive the external token
        ///// - Register the user locally if not already exsist
        ///// - Redirect to 
        ///// </summary>
        ///// <param name="provider">External login provider name. can be either "Facebook" or "Google"</param>
        ///// <param name="redirect_uri">{HOST}/api/account/authcomplete</param>
        ///// <param name="response_type">token (do not pass other types)</param>
        ///// <param name="client_id">"202652240487504" for facebook or "629356712031-g59hjvmolmj5a4lihhirsj5oi4c1oiue.apps.googleusercontent.com" for Google</param>
        ///// <param name="error">Not used directly by you (always ignore)</param>
        ///// <returns></returns>

        //[ApiExplorerSettings(IgnoreApi = true)]
        ////[OverrideAuthentication]
        ////[HostAuthentication(DefaultAuthenticationTypes.ExternalBearer)]
        //[AllowAnonymous]
        //[Route("ExternalLogin", DisplayName = "ExternalLogin")]
        //public async Task<ActionResult> GetExternalLogin(string provider, string response_type, string client_id, string redirect_uri, string error = null, string deviceId = null)
        //{
        //    string redirectUri = string.Empty;
        //    if (error != null)
        //    {
        //        return Redirect(Url.Content("~/") + "#error=" + Uri.EscapeDataString(error));
        //    }

        //    if (!User.Identity.IsAuthenticated)
        //    {
        //        return new ChallengeResult(provider, this);
        //    }

        //    var redirectUriValidationResult = ValidateClientAndRedirectUri(Request, ref redirectUri);

        //    if (!string.IsNullOrWhiteSpace(redirectUriValidationResult))
        //    {
        //        return BadRequest(redirectUriValidationResult);
        //    }

        //    var data = ExternalLoginData.FromIdentity(User.Identity as ClaimsIdentity);

        //    if (data == null)
        //    {
        //        return BadRequest();
        //    }

        //    if (data.LoginProvider != provider)
        //    {
        //        Authentication.SignOut(DefaultAuthenticationTypes.ExternalCookie);
        //        return new ChallengeResult(provider, this);
        //    }

        //    //var user = await _userManager.FindAsync(new UserLoginInfo(data.LoginProvider, data.ProviderKey));

        //    //var hasRegistered = user != null;

        //    //if (hasRegistered)
        //    //{
        //    //    Authentication.SignOut(DefaultAuthenticationTypes.ExternalCookie);

        //    //    ClaimsIdentity oAuthIdentity = await _userManager.CreateIdentityAsync(user, OAuthDefaults.AuthenticationType);
        //    //    ClaimsIdentity cookieIdentity = await _userManager.CreateIdentityAsync(user, CookieAuthenticationDefaults.AuthenticationType);

        //    //    AuthenticationProperties properties = ApplicationOAuthProvider.CreateProperties(user.UserName);
        //    //    Authentication.SignIn(properties, oAuthIdentity, cookieIdentity);
        //    //}
        //    //else
        //    //{
        //    //    IEnumerable<Claim> claims = externalLogin.GetClaims();
        //    //    ClaimsIdentity identity = new ClaimsIdentity(claims, OAuthDefaults.AuthenticationType);
        //    //    Authentication.SignIn(identity);
        //    //}

        //    var verifiedAccessToken = await VerifyExternalAccessToken(data.LoginProvider, data.ExternalAccessToken);
        //    if (verifiedAccessToken == null)
        //    {
        //        return BadRequest($"Invalid Provider ({data.LoginProvider}) or External Access Token ({data.ExternalAccessToken})");
        //    }
        //    var user = await _userManager.FindAsync(new UserLoginInfo(data.LoginProvider, verifiedAccessToken.user_id));

        //    var hasRegistered = user != null;

        //    if (hasRegistered)
        //    {
        //        //Authentication.SignOut(DefaultAuthenticationTypes.ExternalCookie);
        //        redirectUri = $"/api/Account/ObtainLocalAccessToken?externalAccessToken={data.ExternalAccessToken}&provider={data.LoginProvider}";
        //        return Redirect(new Uri(redirectUri, UriKind.Relative));
        //    }

        //    user = new AppUser { UserName = data.UserName, Email = data.Email, DisplayName = data.DisplayName };

        //    var result = await _userManager.CreateAsync(user);
        //    if (!result.Succeeded)
        //    {
        //        return GetErrorResult(result);
        //    }

        //    result = await _userManager.AddToRoleAsync(user.Id, "مستخدم");
        //    if (!result.Succeeded)
        //    {
        //        return GetErrorResult(result);
        //    }
        //    // Create default chat message
        //    _chatMessage.Create(ChatMessage.Create("مرحبا بك في تطبيق السوريون حول العالم! لا تتردد في التواصل مع الإدارة لطلب إعلانات مميزة تظهر أعلى القائمة!", AppStaticConfiguration.AdminId, user.Id));

        //    var info = new ExternalLoginInfo
        //    {
        //        DefaultUserName = data.UserName,
        //        Login = new UserLoginInfo(data.LoginProvider, verifiedAccessToken.user_id)
        //    };

        //    result = await _userManager.AddLoginAsync(user.Id, info.Login);
        //    if (!result.Succeeded)
        //    {
        //        return GetErrorResult(result);
        //    }

        //    if (!string.IsNullOrWhiteSpace(deviceId))
        //    {
        //        user.DeviceId = deviceId;
        //        _userManager.Update(user);
        //    }

        //    //generate access token response
        //    var accessTokenResponse = GenerateLocalAccessTokenResponse(user);

        //    return Ok(accessTokenResponse);

        //    //redirectUri = $"{redirectUri}#external_access_token={data.ExternalAccessToken}&provider={data.LoginProvider}&haslocalaccount={hasRegistered}&external_user_name={data.UserName}&external_display_name={data.DisplayName}&external_email={data.Email}";
        //    //return Redirect(redirectUri);
        //}

        // GET api/Account/ExternalLogins?returnUrl=%2F&generateState=true
        //[ApiExplorerSettings(IgnoreApi = true)]
        //[AllowAnonymous]
        //[Route("ExternalLogins")]
        //public IEnumerable<ExternalLoginViewModel> GetExternalLogins(string returnUrl, bool generateState = false)
        //{
        //    IEnumerable<AuthenticationDescription> descriptions = Authentication.GetExternalAuthenticationTypes();
        //    List<ExternalLoginViewModel> logins = new List<ExternalLoginViewModel>();

        //    string state;

        //    if (generateState)
        //    {
        //        const int strengthInBits = 256;
        //        state = RandomOAuthStateGenerator.Generate(strengthInBits);
        //    }
        //    else
        //    {
        //        state = null;
        //    }

        //    foreach (AuthenticationDescription description in descriptions)
        //    {
        //        ExternalLoginViewModel login = new ExternalLoginViewModel
        //        {
        //            DisplayName = description.DisplayName,
        //            Url = Url.Route("ExternalLogin", new
        //            {
        //                provider = description.AuthenticationType,
        //                response_type = "token",
        //                client_id = Startup.PublicClientId,
        //                redirect_uri = new Uri(Request.RequestUri, returnUrl).AbsoluteUri,
        //                state
        //            }),
        //            State = state
        //        };
        //        logins.Add(login);
        //    }

        //    return logins;
        //}
        // POST api/Account/RegisterExternal
        // [OverrideAuthentication]
        // [HostAuthentication(DefaultAuthenticationTypes.ExternalBearer)]
        //[Route("RegisterExternal")]
        //public async Task<ActionResult> RegisterExternal(RegisterExternalBindingModel model)
        //{
        //    if (!ModelState.IsValid)
        //    {
        //        return BadRequest(ModelState);
        //    }

        //    var verifiedAccessToken = await VerifyExternalAccessToken(model.Provider, model.ExternalAccessToken);
        //    if (verifiedAccessToken == null)
        //    {
        //        return BadRequest("Invalid Provider or External Access Token");
        //    }

        //    try
        //    {

        //        var data = await ExternalLoginData.FromToken(model.Provider, model.ExternalAccessToken);

        //        var user = await _userManager.FindAsync(new UserLoginInfo(model.Provider, verifiedAccessToken.user_id)) ??
        //                   await _userManager.FindByEmailAsync(data.Email) ??
        //                   await _userManager.FindByNameAsync(data.Email);
        //        var hasRegistered = user != null;

        //        if (hasRegistered)
        //        {
        //            if (!user.IsActive)
        //            {
        //                return Content(HttpStatusCode.BadRequest, "الحساب غير مفعل!");
        //            }

        //            if (!string.IsNullOrWhiteSpace(model.DeviceId))
        //            {
        //                user.DeviceId = model.DeviceId;
        //                _userManager.Update(user);
        //            }
        //            return Ok(GenerateLocalAccessTokenResponse(user));
        //        }


        //        user = new AppUser
        //        {
        //            UserName = data.Email,
        //            Email = data.Email,
        //            DisplayName = data.DisplayName,
        //            IsActive = true,
        //            DeviceId = model.DeviceId,
        //            EmailConfirmed = true
        //        };

        //        var result = await _userManager.CreateAsync(user);
        //        if (!result.Succeeded)
        //        {
        //            return GetErrorResult(result);
        //        }

        //        result = await _userManager.AddToRoleAsync(user.Id, "مستخدم");
        //        if (!result.Succeeded)
        //        {
        //            return GetErrorResult(result);
        //        }
        //        // Create default chat message
        //        //_chatMessage.Create(ChatMessage.Create("مرحبا بك في تطبيق السوريون حول العالم! لا تتردد في التواصل مع الإدارة لطلب إعلانات مميزة تظهر أعلى القائمة!", AppStaticConfiguration.AdminId, user.Id));

        //        var info = new ExternalLoginInfo
        //        {
        //            DefaultUserName = data.UserName,
        //            Login = new UserLoginInfo(data.LoginProvider, verifiedAccessToken.user_id)
        //        };

        //        result = await _userManager.AddLoginAsync(user.Id, info.Login);
        //        if (!result.Succeeded)
        //        {
        //            return GetErrorResult(result);
        //        }

        //        if (!string.IsNullOrWhiteSpace(model.DeviceId))
        //        {
        //            user.DeviceId = model.DeviceId;
        //            await _userManager.UpdateAsync(user);
        //        }
        //        //generate access token response
        //        var accessTokenResponse = GenerateLocalAccessTokenResponse(user);

        //        return Ok(accessTokenResponse);
        //    }
        //    catch (Exception ex)
        //    {
        //        return BadRequest(ex.Message + ex.StackTrace);
        //    }
        //}


    }
}
