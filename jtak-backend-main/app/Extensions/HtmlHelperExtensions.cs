using Microsoft.AspNetCore.Mvc.Razor;
using Microsoft.AspNetCore.Mvc.Rendering;
using System;

namespace App.Extensions
{
    public static class HtmlHelperExtensions
    {
        ///<summary>
        /// Adds a partial view script to the Http context to be rendered in the parent view
        /// </summary>

        public static IHtmlHelper Script(this IHtmlHelper htmlHelper, Func<object, HelperResult> template)
        {
            htmlHelper.ViewContext.HttpContext.Items["_script_" + Guid.NewGuid()] = template;
            return null;
        }

        ///<summary>
        /// Renders any scripts used within the partial views
        /// </summary>
        public static IHtmlHelper RenderScripts(this IHtmlHelper htmlHelper)
        {
            foreach (object key in htmlHelper.ViewContext.HttpContext.Items.Keys)
            {
                if (key.ToString().StartsWith("_script_"))
                {
                    var template = htmlHelper.ViewContext.HttpContext.Items[key] as Func<object, HelperResult>;
                    if (template != null)
                    {
                        htmlHelper.ViewContext.Writer.Write(template(null));
                    }
                }
            }
            return null;
        }
    }
}
