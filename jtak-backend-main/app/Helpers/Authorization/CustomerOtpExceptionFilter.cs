using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace App.Helpers.Authorization
{
    public sealed class CustomerOtpExceptionFilter : IExceptionFilter
    {
        public void OnException(ExceptionContext context)
        {
            if (context.Exception is not CustomerOtpException error) return;
            context.Result = new ObjectResult(new { error = "OTP_REQUEST_FAILED", errorDescription = error.Message })
            { StatusCode = error.StatusCode };
            context.ExceptionHandled = true;
        }
    }
}
