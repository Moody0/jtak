using Microsoft.AspNetCore.Http;
using Solf.Enums;
using Solf.Extensions;
using System.Linq;
using App.Shared.Services;
using App.Shared.Entities;
using AutoMapper;

namespace App.Helpers
{
    public interface ISessionHelper
    {
        UserDto CurrentUser { get; set; }
        CountryEnum? CurrentCountry { get; set; }
    }
    public class SessionHelper : ISessionHelper
    {
        private readonly IHttpContextAccessor _httpContextAccessor;
        private readonly IUserService _userService;
        private readonly IMapper _mapper;
        //private readonly UserManager<AppUser> _userManager;
        private ISession _session => _httpContextAccessor.HttpContext.Session;

        public SessionHelper(IHttpContextAccessor httpContextAccessor, IUserService userService, IMapper mapper)
        {
            _httpContextAccessor = httpContextAccessor;
            _userService = userService;
            _mapper = mapper;
        }
        /*
        public UserVm CurrentUser
        {
            get => _session.Get<UserVm>("CurrentUser");
            set => _session.Set("CurrentUser", value);
        }*/
        public UserDto CurrentUser
        {
            get
            {
                var cu = _session.Get<UserDto>("CurrentUser");
                if (cu != null) return cu;
                var un = _httpContextAccessor.HttpContext.User?.Identity?.Name;
                var user = _userService.Queryable().FirstOrDefault(x => x.UserName == un);
                var model = _mapper.Map<UserDto>(user);
                _session.Set("CurrentUser", model);
                return _session.Get<UserDto>("CurrentUser");
            }
            set { _session.Set("CurrentUser", value); }
        }
        public CountryEnum? CurrentCountry
        {
            get => _session.GetCountryEnum("CurrentCountry");
            set => _session.SetCountryEnum("CurrentCountry", value);
        }
    }
}
