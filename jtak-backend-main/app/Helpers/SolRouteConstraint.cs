using App.Shared.Services.Options;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Options;
using System;
using System.Linq;

namespace App.Helpers
{
    public class SolRouteConstraint : IRouteConstraint
    {
        private SolAppOptions _options { get; set; }
        public SolRouteConstraint(IOptions<SolAppOptions> options)
        {
            _options = options.Value;
        }
        public bool Match(HttpContext httpContext, IRouter route, string routeKey, RouteValueDictionary values, RouteDirection routeDirection)
        {
            if (!values.ContainsKey("culture")) return false;

            var culture = values["culture"].ToString();

            return _options.SupportedLanguages.Contains(culture);
        }
    }
}
