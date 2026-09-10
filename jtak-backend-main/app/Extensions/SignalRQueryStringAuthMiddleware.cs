using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;

namespace App.Extensions
{

    public class QueryStringAuthMiddleware
    {
        private readonly RequestDelegate _next;

        public QueryStringAuthMiddleware(RequestDelegate next)
        {
            _next = next;
        }

        // Convert incomming qs auth token to a Authorization header so the rest of the chain
        // can authorize the request correctly
        public async Task Invoke(HttpContext context)
        {
            if (context.Request.Query.TryGetValue("token", out var token))
            {
                context.Request.Headers.Add("Authorization", "Bearer " + token.First());
            }
            await _next.Invoke(context);
        }
    }

    public static class QueryStringAuthExtensions
    {
        public static IApplicationBuilder UseQueryStringAuth(this IApplicationBuilder builder) =>
            builder.UseMiddleware<QueryStringAuthMiddleware>();
    }
}
