using System;
using System.Linq;
using Microsoft.AspNetCore.Mvc.Rendering;

namespace App.Helpers
{
    public static class HtmlHelpers
    {
        public static string isActive(this IHtmlHelper html, string actions = null, string controllers = null, params bool[] extraConditions)
        {
            const string activeClass = "active"; // change here if you another name to activate sidebar items
            // detect current app state
            var actualAction = (string)html.ViewContext.RouteData.Values["action"];
            var actualController = (string)html.ViewContext.RouteData.Values["controller"];

            if (string.IsNullOrEmpty(controllers)) controllers = actualController;

            if (string.IsNullOrEmpty(actions)) actions = actualAction;

            var activeController = controllers.Split(",", StringSplitOptions.RemoveEmptyEntries).Any(c => c == actualController);
            var activeAction = actions.Split(",", StringSplitOptions.RemoveEmptyEntries).Any(c => c == actualAction);

            var isActive = (!extraConditions.Any() && activeController && activeAction) || 
                (extraConditions.Any() && extraConditions.All(x => x) && activeController && activeAction);
            
            return isActive ? activeClass : string.Empty;
        }
    }
}
