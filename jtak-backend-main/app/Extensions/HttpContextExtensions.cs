using Microsoft.AspNetCore.Http;

namespace App.Extensions
{
    public static class HttpContextExtensions
    {
        public static string AbsoluteUri(this IHttpContextAccessor ctx) => string.Concat(ctx.BaseUri(),
                ctx.HttpContext.Request.PathBase.ToUriComponent(),
                ctx.HttpContext.Request.Path.ToUriComponent(),
                ctx.HttpContext.Request.QueryString.ToUriComponent());
        public static string BaseUri(this IHttpContextAccessor ctx) => string.Concat(
                ctx.HttpContext.Request.Scheme,
                "://",
                ctx.HttpContext.Request.Host.ToUriComponent());
    }
}
