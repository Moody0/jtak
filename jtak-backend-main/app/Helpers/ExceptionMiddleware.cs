using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using App.ApiModels;
using System;
using System.Net;
using System.Threading.Tasks;
using System.Text.Json;

namespace App.Helpers
{
    public class ExceptionMiddleware
    {
        private readonly RequestDelegate _next;
        private readonly ILogger _logger;
        private readonly IWebHostEnvironment _env;

        public ExceptionMiddleware(RequestDelegate next, ILogger<ExceptionMiddleware> logger, IWebHostEnvironment env)
        {
            _logger = logger;
            _env = env;
            _next = next;
        }

        public async Task InvokeAsync(HttpContext context)
        {
            try
            {
                await _next(context);
            }
            catch (Exception ex)
            {
                if (context.Response.HasStarted)
                {
                    _logger.LogWarning("The response has already started, the http status code middleware will not be executed.");
                    throw;
                }

                // Log the error
                _logger.LogError(ex, ex.Message + Environment.NewLine + ex.StackTrace);

                // Don't handel non-api exceptions (for now)
                if (!context.Request.Path.StartsWithSegments("/api", StringComparison.OrdinalIgnoreCase)) throw;

                context.Response.Clear();

                context.Response.ContentType = "application/json";
                context.Response.StatusCode = (int)HttpStatusCode.InternalServerError;

                var response = _env.IsDevelopment()
                    ? ApiErr.Create(ex)
                    : ApiErr.Create(ex);// ApiErr.Create(_Errors.ErrorTryLater);

                await context.Response.WriteAsync(JsonSerializer.Serialize(response));

            }
        }
    }
}
