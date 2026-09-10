using App.ApiModels;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.ModelBinding;
using System;
using System.Collections.Generic;

namespace App.ApiControllers
{
    [ApiController, Produces("application/json")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    public class SolApiController : ControllerBase
    {
        [NonAction]
        public BadRequestObjectResult BadRequest(params string[] msgs) =>
            base.BadRequest(ApiErr.Create(msgs));

        [NonAction]
        public BadRequestObjectResult BadRequest(IEnumerable<string> msgs) =>
            base.BadRequest(ApiErr.Create(msgs));

        [NonAction]
        public BadRequestObjectResult BadRequest(IdentityResult result) =>
            base.BadRequest(ApiErr.Create(result));

        public override BadRequestObjectResult BadRequest(ModelStateDictionary modelState) =>
            base.BadRequest(ApiErr.Create(modelState));

        [NonAction]
        public UnauthorizedObjectResult Unauthorized(string str) =>
            base.Unauthorized(ApiErr.Create(str));

        [NonAction]
        public BadRequestObjectResult BadRequest(Exception ex) =>
            base.BadRequest(ApiErr.Create(ex));
    }
}
