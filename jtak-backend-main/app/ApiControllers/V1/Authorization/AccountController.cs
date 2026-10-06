using Microsoft.Extensions.Caching.Memory;
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
using Microsoft.Extensions.Configuration;
using System.Security.Cryptography;

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
        private readonly IConfiguration _configuration;
        private readonly App.Catalog.Data.CatalogDbContext _catalog;
        private readonly IMemoryCache _cache;

        private bool IsTemporaryOtpEnabled =>
            bool.TryParse(_configuration?["Authentication:TemporaryOtpEnabled"], out var enabled) && enabled;

        private string TemporaryOtpCode
        {
            get
            {
                var configuredCode = _configuration?["Authentication:TemporaryOtpCode"]?.Trim();
                return !string.IsNullOrEmpty(configuredCode) && configuredCode.Length == 6 && configuredCode.All(char.IsDigit)
                    ? configuredCode
                    : "123456";
            }
        }

        public AccountController(IAppUnitOfWork unitOfWorkAsync,
            UserManager<AppUser> userManager,
            IMapper mapper,
            ILogger<AccountController> logger,
            ISmsLogService smsLogService,
            IEmailService emailService,
            INotificationService notificationService,
            IConfiguration configuration = null,
            App.Catalog.Data.CatalogDbContext catalog = null,
            IMemoryCache cache = null)
        {
            _unitOfWork = unitOfWorkAsync;
            _userManager = userManager;
            _mapper = mapper;
            _logger = logger;
            _smsLogService = smsLogService;
            _emailService = emailService;
            _notificationService = notificationService;
            _configuration = configuration;
            _catalog = catalog;
            _cache = cache;
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

            var phoneNumber = model.PhoneNumber;
            if (!string.IsNullOrWhiteSpace(phoneNumber) && SyrianPhoneIdentity.TryNormalize(phoneNumber, out var canonicalPhone))
            {
                var existing = await SyrianPhoneIdentity.FindAsync(_userManager, canonicalPhone);
                if (existing.Ambiguous || existing.User != null)
                    return StatusCode(409, new { error = "PHONE_ALREADY_REGISTERED", errorDescription = "رقم الهاتف مرتبط بحساب موجود بالفعل." });
                phoneNumber = canonicalPhone;
            }

            var user = new AppUser
            {
                UserName = model.Email,
                Email = model.Email,
                PhoneNumber = phoneNumber,
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
                var code = await _userManager.GenerateChangePhoneNumberTokenAsync(user, phoneNumber);
                var msg = string.Format(_Account.SmsVerification, code);
                try
                {
                    var response = await _notificationService.SendSmsNotification(phoneNumber, msg);
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
            if (!SyrianPhoneIdentity.TryNormalize(model.PhoneNumber, out var canonicalPhone)) return BadRequest(_Errors.InvalidNumber);
            var match = await SyrianPhoneIdentity.FindAsync(_userManager, canonicalPhone);
            if (match.Ambiguous) return StatusCode(409, new { error = "PHONE_ACCOUNT_AMBIGUOUS", errorDescription = "يوجد أكثر من حساب مرتبط بهذا الرقم. يرجى التواصل مع الدعم." });
            var user = match.User;
            if (user?.DeletionDate != null) return NotFound();
            if (user != null && !user.IsActive)
                return StatusCode(403, new
                {
                    error = "ACCOUNT_DISABLED",
                    errorDescription = "تم تعطيل حسابك. يرجى التواصل مع الدعم الفني."
                });
            //var waitTimeInSecs = await _smsLogService.GetSMSResendWaitTime(user?.Id);
            var waitTimeInSecs = 0;

            if (waitTimeInSecs > 0)
                return BadRequest($"You need to wait {waitTimeInSecs}s");

            var pending = await _unitOfWork.Context.PendingPhoneSignups.FindAsync(canonicalPhone);
            if (pending != null && (user == null || !HasCompletedProfileName(user)))
            {
                pending.Code = CreatePhoneSignupCode();
                pending.ExpiresAt = DateTime.UtcNow.AddMinutes(10);
                pending.FailedAttempts = 0;
                await _unitOfWork.SaveChangesAsync();
                var pendingMessage = string.Format(_Account.SmsVerification, pending.Code);
                await SendOtpSmsAsync(canonicalPhone, pendingMessage);
                return waitTimeInSecs;
            }

            if (pending != null)
            {
                _unitOfWork.Context.PendingPhoneSignups.Remove(pending);
                await _unitOfWork.SaveChangesAsync();
            }
            if (user == null || user.DeletionDate != null) return NotFound();

            var code = await _userManager.GenerateChangePhoneNumberTokenAsync(user, canonicalPhone);
            var msg = string.Format(_Account.SmsVerification, code);
            var response = await SendOtpSmsAsync(canonicalPhone, msg);
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
        public async Task<ActionResult<PhoneSignInStartResponse>> RegisterOrSignInByPhoneNumber(PhoneNumberModel model)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);
            if (!SyrianPhoneIdentity.TryNormalize(model.PhoneNumber, out var canonicalPhone)) return BadRequest(_Errors.InvalidNumber);

            await _unitOfWork.Context.PendingPhoneSignups
                .Where(x => x.ExpiresAt <= DateTime.UtcNow)
                .ExecuteDeleteAsync();
            var match = await SyrianPhoneIdentity.FindAsync(_userManager, canonicalPhone);
            if (match.Ambiguous) return StatusCode(409, new { error = "PHONE_ACCOUNT_AMBIGUOUS", errorDescription = "يوجد أكثر من حساب مرتبط بهذا الرقم. يرجى التواصل مع الدعم." });
            var user = match.User;
            if (user?.DeletionDate != null) return NotFound();
            if (user != null && !user.IsActive)
                return StatusCode(403, new
                {
                    error = "ACCOUNT_DISABLED",
                    errorDescription = "تم تعطيل حسابك. يرجى التواصل مع الدعم الفني."
                });

            // New signups and legacy accounts without a real name stay outside
            // AppUsers until profile completion. This keeps abandoned OTP
            // attempts from becoming nameless customer accounts.
            if (user == null || !HasCompletedProfileName(user))
            {
                var pending = await _unitOfWork.Context.PendingPhoneSignups.FindAsync(canonicalPhone);
                if (pending == null)
                {
                    pending = new PendingPhoneSignup { PhoneNumber = canonicalPhone };
                    _unitOfWork.Context.PendingPhoneSignups.Add(pending);
                }
                pending.Code = CreatePhoneSignupCode();
                pending.ExpiresAt = DateTime.UtcNow.AddMinutes(10);
                pending.FailedAttempts = 0;
                await _unitOfWork.SaveChangesAsync();
                var msg = string.Format(_Account.SmsVerification, pending.Code);
                await SendOtpSmsAsync(canonicalPhone, msg);

                return new PhoneSignInStartResponse
                {
                    RequiresProfileCompletion = true,
                    VerificationCode = GetVerificationCodeForClient(pending.Code)
                };
            }

            var code = await _userManager.GenerateChangePhoneNumberTokenAsync(user, canonicalPhone);
            var smsMessage = string.Format(_Account.SmsVerification, code);
            var smsResponse = await SendOtpSmsAsync(canonicalPhone, smsMessage);
            _smsLogService.Insert(new SmsLog { UserId = user.Id, Code = code, Text = smsMessage, Response = smsResponse });
            await _unitOfWork.SaveChangesAsync();

            return new PhoneSignInStartResponse
            {
                RequiresProfileCompletion = false,
                VerificationCode = GetVerificationCodeForClient(code)
            };
        }

        [AllowAnonymous, HttpPost, Route("VerifyPhoneSignupCode")]
        public async Task<ActionResult<string>> VerifyPhoneSignupCode(PhoneNumberCodeModel model)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);
            if (!SyrianPhoneIdentity.TryNormalize(model.PhoneNumber, out var canonicalPhone)) return BadRequest(_Errors.InvalidNumber);

            var pending = await _unitOfWork.Context.PendingPhoneSignups.FindAsync(canonicalPhone);
            if (pending == null || pending.ExpiresAt <= DateTime.UtcNow)
                return BadRequest("انتهت صلاحية رمز التحقق. يرجى طلب رمز جديد.");
            if (pending.FailedAttempts >= 5)
                return BadRequest("تم تجاوز عدد المحاولات. يرجى طلب رمز جديد.");

            if (!IsPhoneSignupCodeValid(pending, model.Code.Trim()))
            {
                pending.FailedAttempts++;
                await _unitOfWork.SaveChangesAsync();
                return BadRequest(_Errors.InvalidCode);
            }

            return "OK";
        }

        [AllowAnonymous, HttpPost, Route("CompletePhoneSignUp")]
        public async Task<ActionResult<string>> CompletePhoneSignUp(CompletePhoneSignupModel model)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);
            if (!SyrianPhoneIdentity.TryNormalize(model.PhoneNumber, out var canonicalPhone)) return BadRequest(_Errors.InvalidNumber);

            var pending = await _unitOfWork.Context.PendingPhoneSignups.FindAsync(canonicalPhone);
            if (pending == null || pending.ExpiresAt <= DateTime.UtcNow)
            {
                if (pending != null)
                {
                    _unitOfWork.Context.PendingPhoneSignups.Remove(pending);
                    await _unitOfWork.SaveChangesAsync();
                }
                return BadRequest("انتهت صلاحية رمز التحقق. يرجى طلب رمز جديد.");
            }

            if (pending.FailedAttempts >= 5)
                return BadRequest("تم تجاوز عدد المحاولات. يرجى طلب رمز جديد.");

            var enteredCode = model.Code.Trim();
            if (!IsPhoneSignupCodeValid(pending, enteredCode))
            {
                pending.FailedAttempts++;
                await _unitOfWork.SaveChangesAsync();
                return BadRequest(_Errors.InvalidCode);
            }

            var match = await SyrianPhoneIdentity.FindAsync(_userManager, canonicalPhone);
            if (match.Ambiguous) return StatusCode(409, new { error = "PHONE_ACCOUNT_AMBIGUOUS", errorDescription = "يوجد أكثر من حساب مرتبط بهذا الرقم. يرجى التواصل مع الدعم." });
            var user = match.User;
            if (user?.DeletionDate != null) return NotFound();
            if (user != null && !user.IsActive)
                return StatusCode(403, new
                {
                    error = "ACCOUNT_DISABLED",
                    errorDescription = "تم تعطيل حسابك. يرجى التواصل مع الدعم الفني."
                });
            if (user != null && HasCompletedProfileName(user))
                return Conflict("هذا الرقم مسجل بالفعل. يرجى تسجيل الدخول.");

            var fullName = model.FullName.Trim();
            var splitIndex = fullName.IndexOf(' ');
            var firstName = splitIndex >= 0 ? fullName.Substring(0, splitIndex).Trim() : fullName;
            var lastName = splitIndex >= 0 ? fullName.Substring(splitIndex + 1).Trim() : string.Empty;

            if (user == null)
            {
                user = new AppUser
                {
                    UserName = canonicalPhone,
                    PhoneNumber = canonicalPhone,
                    PhoneNumberConfirmed = true,
                    IsActive = true,
                    FirstName = firstName,
                    LastName = lastName,
                    FullName = fullName
                };
                var createResult = await _userManager.CreateAsync(user);
                if (!createResult.Succeeded)
                {
                    var racedMatch = await SyrianPhoneIdentity.FindAsync(_userManager, canonicalPhone);
                    if (racedMatch.User == null || racedMatch.Ambiguous) return Conflict(createResult);
                    user = racedMatch.User;
                    if (HasCompletedProfileName(user)) return Conflict("هذا الرقم مسجل بالفعل. يرجى تسجيل الدخول.");
                }
                else
                {
                    var roleResult = await _userManager.AddToRoleAsync(user, AppRoleName.Customer.ToString());
                    if (!roleResult.Succeeded)
                    {
                        await _userManager.DeleteAsync(user);
                        return BadRequest(roleResult);
                    }
                }
            }
            else
            {
                user.FirstName = firstName;
                user.LastName = lastName;
                user.FullName = fullName;
                user.PhoneNumber = canonicalPhone;
                user.PhoneNumberConfirmed = true;
                var updateResult = await _userManager.UpdateAsync(user);
                if (!updateResult.Succeeded) return BadRequest(updateResult);
            }

            _smsLogService.Insert(new SmsLog
            {
                UserId = user.Id,
                Code = enteredCode,
                Text = string.Format(_Account.SmsVerification, enteredCode)
            });
            _unitOfWork.Context.PendingPhoneSignups.Remove(pending);
            await _unitOfWork.SaveChangesAsync();
            return "OK";
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
            if (!ModelState.IsValid) return BadRequest(ModelState);
            if (!SyrianPhoneIdentity.TryNormalize(model.PhoneNumber, out var canonicalPhone)) return BadRequest(_Errors.InvalidNumber);
            var match = await SyrianPhoneIdentity.FindAsync(_userManager, canonicalPhone);
            if (match.Ambiguous) return StatusCode(409, new { error = "PHONE_ACCOUNT_AMBIGUOUS", errorDescription = "يوجد أكثر من حساب مرتبط بهذا الرقم. يرجى التواصل مع الدعم." });
            var user = match.User;

            // 1. Verify user exists and has the Merchant role
            if (user == null || user.DeletionDate != null || !await _userManager.IsInRoleAsync(user, AppRoleName.Merchant.ToString()))
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

            var code = await _userManager.GenerateChangePhoneNumberTokenAsync(user, canonicalPhone);
            var msg = string.Format(_Account.SmsVerification, code);

            var response = await SendOtpSmsAsync(canonicalPhone, msg);
            _smsLogService.Insert(new SmsLog { UserId = user.Id, Code = code, Text = msg, Response = response });

            await _unitOfWork.SaveChangesAsync();

            return GetVerificationCodeForClient(code);
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

            if (!SyrianPhoneIdentity.TryNormalize(model?.PhoneNumber, out var canonicalPhone)) return BadRequest(_Errors.InvalidNumber);
            var match = await SyrianPhoneIdentity.FindAsync(_userManager, canonicalPhone);
            if (match.Ambiguous) return StatusCode(409, new { error = "PHONE_ACCOUNT_AMBIGUOUS", errorDescription = "يوجد أكثر من حساب مرتبط بهذا الرقم. يرجى التواصل مع الدعم." });
            var user = match.User;
            if (user == null) return BadRequest(_Errors.InvalidCode);
            var result = await _userManager.ChangePhoneNumberAsync(user, canonicalPhone, model?.Code);

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

            if (user == null)
                return Unauthorized();

            if (!string.IsNullOrWhiteSpace(vm.FullName))
            {
                var full = vm.FullName.Trim();
                user.FullName = full;
                var spaceIndex = full.IndexOf(' ');
                if (spaceIndex > 0)
                {
                    user.FirstName = full.Substring(0, spaceIndex).Trim();
                    user.LastName = full.Substring(spaceIndex + 1).Trim();
                }
                else
                {
                    user.FirstName = full;
                    user.LastName = "";
                }
            }

            if (!string.IsNullOrWhiteSpace(vm.ProfilePhoto))
                user.ProfilePhoto = vm.ProfilePhoto;

            if (!string.IsNullOrWhiteSpace(vm.PhoneNumber))
            {
                var requestedPhone = vm.PhoneNumber.Trim();
                if (SyrianPhoneIdentity.TryNormalize(requestedPhone, out var canonicalPhone))
                {
                    var match = await SyrianPhoneIdentity.FindAsync(_userManager, canonicalPhone);
                    if (match.Ambiguous || (match.User != null && match.User.Id != user.Id))
                        return StatusCode(409, new { error = "PHONE_ALREADY_REGISTERED", errorDescription = "رقم الهاتف مرتبط بحساب آخر." });
                    requestedPhone = canonicalPhone;
                }
                user.PhoneNumber = requestedPhone;
            }

            if (!string.IsNullOrWhiteSpace(vm.CountryPhoneCode))
                user.CountryPhoneCode = vm.CountryPhoneCode.Trim();

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
                user.Email = vm.Email.Trim();
            }

            user.UpdatedDate = DateTime.UtcNow;

            var result = await _userManager.UpdateAsync(user);
            if (!result.Succeeded) return BadRequest(result);
            await _unitOfWork.SaveChangesAsync();

            if (_catalog != null && !string.IsNullOrWhiteSpace(user.FullName))
            {
                try
                {
                    var ownedMerchants = await _catalog.Merchants
                        .Where(m => m.OwnerId == user.Id && m.DeletionDate == null)
                        .ToListAsync();
                    if (ownedMerchants.Any())
                    {
                        foreach (var m in ownedMerchants)
                        {
                            if (!string.IsNullOrWhiteSpace(user.FullName))
                            {
                                m.OwnerName = user.FullName;
                            }
                            if (!string.IsNullOrWhiteSpace(user.PhoneNumber))
                            {
                                m.Phone1 = user.PhoneNumber;
                            }
                            if (!string.IsNullOrWhiteSpace(user.ProfilePhoto) && string.IsNullOrWhiteSpace(m.Photo))
                            {
                                m.Photo = $"{user.ProfilePhoto},{user.ProfilePhoto}";
                            }

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
                    _logger.LogWarning($"Failed to sync merchant owner name: {ex.Message}");
                }
            }
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

        private static string CreatePhoneSignupCode() =>
            RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");

        private bool IsPhoneSignupCodeValid(PendingPhoneSignup pending, string code) =>
            (IsTemporaryOtpEnabled && string.Equals(TemporaryOtpCode, code, StringComparison.Ordinal)) ||
            string.Equals(pending.Code, code, StringComparison.Ordinal);

        private async Task<string> SendOtpSmsAsync(string phoneNumber, string message)
        {
            if (IsTemporaryOtpEnabled) return string.Empty;

            try
            {
                return await _notificationService.SendSmsNotification(phoneNumber, message);
            }
            catch (Exception exception) when (IsTemporaryOtpEnabled)
            {
                _logger.LogWarning(exception,
                    "OTP SMS delivery failed while temporary OTP mode is enabled.");
                return string.Empty;
            }
        }

        private string GetVerificationCodeForClient(string generatedCode)
        {
            if (IsTemporaryOtpEnabled) return TemporaryOtpCode;
#if DEBUG
            return generatedCode;
#else
            return string.Empty;
#endif
        }

        private static bool HasCompletedProfileName(AppUser user)
        {
            var name = user?.FullName?.Trim();
            return !string.IsNullOrWhiteSpace(name) &&
                name != "عميل جيتك" && name != "مستخدم جيتك" &&
                name != "عميل جتاك" && name != "مستخدم جتاك";
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
