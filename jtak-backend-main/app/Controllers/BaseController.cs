using System.Linq;
using AutoMapper;
using App.Shared.Entities;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Solf.Extensions;
using URF.Core.Abstractions;
using Microsoft.Extensions.Logging;

namespace App.Controllers
{
    public class BaseController : Controller
    {
        #region Fields

        protected readonly IUnitOfWork UnitOfWork;
        protected readonly IMapper Mapper;
        protected readonly ILogger Logger;
        protected readonly UserManager<AppUser> UserManager;

        public BaseController(IUnitOfWork unitOfWork, IMapper mapper, ILogger logger, UserManager<AppUser> userManager)
        {
            UnitOfWork = unitOfWork;
            Mapper = mapper;
            Logger = logger;
            UserManager = userManager;

            //this._workContext = (WorkContext)AutofacDependencyResolver.Current.GetService(typeof(IWorkContext));

            //this._activityLogService = (ActivityLogService)AutofacDependencyResolver.Current.GetService(typeof(IActivityLogService));
            //this._activityLogService.Init(_workContext.UserId, _workContext.Ip, /*HttpContext.Request?.Url?.ToString() ??*/ "");

            //this._localize = (Localize)AutofacDependencyResolver.Current.GetService(typeof(ILocalize));
        }

        public UserDto CurrentUser
        {
            get
            {
                var cu = HttpContext.Session.Get<UserDto>("CurrentUser");
                if (cu != null) return cu;
                var un = User?.Identity?.Name;
                var user = UserManager.Users.FirstOrDefault(x => x.UserName == un);
                var model = Mapper.Map<AppUser, UserDto>(user);
                HttpContext.Session.Set("CurrentUser", model);
                return HttpContext.Session.Get<UserDto>("CurrentUser");
            }
            set { HttpContext.Session.Set("CurrentUser", value); }
        }

        //public CountryEnum CurrentCountry
        //{
        //    get
        //    {
        //        var cu = HttpContext.Session.GetCountryEnum("CurrentCountry");
        //        if (cu != null) return cu.Value;
        //        CurrentCountry = CurrentUser.CountryId;
        //        return CurrentUser.CountryId;
        //    }
        //    set => HttpContext.Session.SetCountryEnum("CurrentCountry", value);
        //}
        //protected LanguageCode CurrentLanguage = CultureHelper.CurrentLanguageCode;

        //protected IActivityLogService _activityLogService { set; get; }

        //protected IWorkContext _workContext { set; get; }

        //protected ILocalize _localize;
        #endregion

        #region Errors 

        public ActionResult NotFound()
        {
            return RedirectToAction("NotFound", "Error", new {area = ""});
        }

        protected ActionResult InternalServerError()
        {
            return RedirectToAction("InternalServerError", "Error", new { area = "" });
        }

        protected ActionResult AccessDenied()
        {
            return RedirectToAction("AccessDenied", "Error", new { area = "" });
        }

        protected ActionResult BadRequest()
        {
            return RedirectToAction("BadRequest", "Error", new { area = "" });
        }
        #endregion

        [TempData]
        public string Message { get; set; }
        [TempData]
        public string MessageType { get; set; }

        protected void SetToastr(string message, string type = "success")
        {
            Message = message;
            MessageType = type;
        }
    }
}
