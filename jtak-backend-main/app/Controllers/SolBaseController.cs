using System.Linq;
using AutoMapper;
using App.Shared.Entities;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Solf.Extensions;
using App.Shared.Data.App;

namespace App.Controllers
{
    public class SolBaseController : Controller
    {
        #region Fields

        protected readonly IAppUnitOfWork UnitOfWork;
        protected readonly IMapper Mapper;
        protected readonly ILogger Logger;
        protected readonly UserManager<AppUser> UserManager;

        public SolBaseController(IAppUnitOfWork unitOfWork, IMapper mapper, ILogger logger, UserManager<AppUser> userManager)
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

        //public ActionResult NotFound()
        //{
        //    //todo design should be regardlss of corporate or host
        //    // or you should check if corporate => redireto to /corporate/error... or host/error...
        //    //404
        //    //throw new HttpException((int)HttpStatusCode.NotFound, "Your error message");
        //    return RedirectToAction("NotFound", "Error", new {area = ""});
        //}

        //protected ActionResult InternalServerError()
        //{
        //    //500
        //    //throw new HttpException((int)HttpStatusCode.InternalServerError, "Your error message");
        //    return RedirectToAction("InternalServerError", "Error", new { area = "" });
        //}

        //protected ActionResult AccessDenied()
        //{
        //    //403
        //    //throw new HttpException((int)HttpStatusCode.Forbidden, "Your error message");
        //    return RedirectToAction("AccessDenied", "Error", new { area = "" });
        //}

        //protected ActionResult BadRequest()
        //{
        //    //400
        //    //throw new HttpException((int)HttpStatusCode.BadRequest, "Your error message");
        //    return RedirectToAction("BadRequest", "Error", new { area = "" });
        //}
        #endregion

        #region Activity Log
        //protected void LogDebug(string message, string details = "")=>_activityLogService.LogDebug(message,details);
        //protected void LogInfo(string message, string details = "") _activityLogService.LogInfo(message, details);
        //protected void LogWarning(string message, string details = "")=> _activityLogService.LogWarning(message, details);
        //protected void LogFatal(string message, string details = "") _activityLogService.LogFatal(message, details);
        /*
        protected void LogException(Exception ex)
        {
            if (ex is CustomException) return;
            _activityLogService.LogException(ex);
        }
        */
        #endregion
        /*
        protected override void OnException(ExceptionContext filterContext)
        {
            if (filterContext.Exception != null)
                LogException(filterContext.Exception);
            base.OnException(filterContext);
        }
        */
        //protected override void OnActionExecuted(ActionExecutedContext filterContext)
        //{

        //}

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
