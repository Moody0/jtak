using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc.ModelBinding;
using System;
using System.Collections.Generic;
using System.Linq;

namespace App.ApiModels
{
    public class ApiErr
    {
        public static ApiErr Create(params string[] msgs) =>
            new ApiErr { Errors = msgs };

        public static ApiErr Create(IEnumerable<string> msgs) =>
            Create(msgs.ToArray());

        public static ApiErr Create(IdentityResult result) =>
            Create(result.Errors.Select(x => x.Code + ":" + x.Description));

        public static ApiErr Create(ModelStateDictionary modelState) =>
            Create(modelState.Values.SelectMany(x => x.Errors).Select(x => x.ErrorMessage));

        public static ApiErr Create(Exception ex) =>
            Create(ex.Message);

        /// <summary>
        /// List of errors.
        /// </summary>
        public string[] Errors { get; set; } = Array.Empty<string>();

        /// <summary>
        /// Request Id
        /// </summary>
        public string RequestId = Guid.NewGuid().ToString("D");

        /// <summary>
        /// Response TimeStamp
        /// </summary>
        public DateTime TimeStamp = DateTime.UtcNow;
    }
}
