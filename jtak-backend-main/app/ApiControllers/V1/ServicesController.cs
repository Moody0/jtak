
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using System.IO;
using System;
using AutoMapper;
using App.Controllers;
using Microsoft.AspNetCore.Identity;
using App.Shared.Entities;
using SixLabors.ImageSharp.Processing;
using SixLabors.ImageSharp;
using System.Text;
using App.Helpers;
using OpenIddict.Validation.AspNetCore;
using Solf.Helpers;
using App.Shared.Data.App;
using SixLabors.ImageSharp.Formats.Webp;

namespace App.ApiControllers.V1
{
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
    [ApiController]
    [Route("api/v{version:apiVersion}/[controller]")]
    [ApiVersion("1")]
    public class ServicesController : SolBaseController
    {
        private readonly IWebHostEnvironment _env;
        public ServicesController(IAppUnitOfWork UOW,
                                    ILogger<ServicesController> logger,
                                    UserManager<AppUser> userManager,
                                    IMapper mapper,
                                    IWebHostEnvironment env) : base(UOW, mapper, logger, userManager)
        {
            _env = env;
        }

        [HttpPost]
        [Route("SaveUploaded")]
        [Produces("application/json")]
        public async Task<ActionResult<string>> SaveUploaded()
        {
            var files = Request.Form.Files.ToArray();
            var id = await _env.SaveFile(files);

            return id;
        }

        [HttpGet]
        [Route("Download/{id}")]
        [AllowAnonymous]
        public IActionResult Download(string id, string token = "")
        {
            try
            {
                var fullPath = FileHelper.GetPhysicalPath(_env, id);
                if (!System.IO.File.Exists(fullPath)) return NotFound();
                var ext = Path.GetExtension(id)?.ToLower() ?? "";

                return new PhysicalFileResult(fullPath, MimeTypeMap.GetMimeType(ext));
            }
            catch (Exception e)
            {
                return NotFound(e.ToString());
            }
        }


        /// <summary>
        /// 
        /// </summary>
        /// <param name="id"></param>
        /// <param name="fileName">the requested media file, it can be either master.m3u8 or stream.mpd</param>
        /// <param name="token">user access token for authorization</param>
        /// <returns></returns>
        [HttpGet]
        [Route("Play/{id}/{fileName}")]
        [AllowAnonymous]
        public async Task<IActionResult> Play(string id, string fileName = "master.mpd", string token = "")
        {
            try
            {
                var fname = fileName.Split(".")[0];
                var ext = fileName.EndsWith(".mpd") ? ".mpd" : fileName.EndsWith(".m3u8") ? ".m3u8" : fileName.EndsWith(".mp4") ? ".mp4" : null;
                var mimeType = fileName.EndsWith(".mpd") ? "application/dash+xml" : fileName.EndsWith(".m3u8") ? "application/x-mpegURL" : fileName.EndsWith(".mp4") ? (fileName.StartsWith("au-") ? "audio/mp4" : "video/mp4") : null;
                if (ext == null) return BadRequest("Unknown file extension");

                var path = $"{_env.ContentRootPath}\\Streaming\\{id}\\{fileName}";

                if (ext == ".mpd" || ext == ".m3u8")
                {
                    var content = await System.IO.File.ReadAllTextAsync(path);
                    content = content.Replace(".mpd", $".mpd?token={token}")
                        .Replace(".m3u8", $".m3u8?token={token}")
                        .Replace(".mp4", $".mp4?token={token}");
                    return File(Encoding.UTF8.GetBytes(content), mimeType, fileName, true);
                }
                var stream = System.IO.File.OpenRead(path);

                return File(stream, mimeType, fileName, true);
            }
            catch (System.Exception e)
            {
                return Content(e.ToString());
            }
        }


        [AllowAnonymous]
        [Route("PreviewImage/{id?}")]
        [HttpGet]
        public IActionResult PreviewImageApi(string id = "", int w = 150, int h = 150, bool crop = true)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(id)) return NotFound();

                var cleanId = id.Split(',')[0].Trim();
                var physicalPath = FileHelper.GetPhysicalPath(_env, cleanId);
                var ext = Path.GetExtension(cleanId)?.ToLower() ?? "";

                if (!System.IO.File.Exists(physicalPath))
                {
                    physicalPath = Path.Combine(_env.WebRootPath, "images", "default-image.jpg");
                    ext = ".jpg";
                    if (!System.IO.File.Exists(physicalPath))
                    {
                        return NotFound();
                    }
                }

                if (ext == ".svg" || ext == ".webp" || ext == ".gif" || ext == ".avif")
                {
                    return new PhysicalFileResult(physicalPath, MimeTypeMap.GetMimeType(ext));
                }

                var cleanNameWithoutExt = Path.GetFileNameWithoutExtension(cleanId);
                var thumbPhysicalPath = FileHelper.GetPhysicalPath(_env, cleanNameWithoutExt) + $"{w}x{h}{(crop ? "c" : "")}" + ext;
                var resizeOptions = new ResizeOptions { Size = new Size(w, h), Mode = crop ? ResizeMode.Crop : ResizeMode.Min };

                if (!System.IO.File.Exists(thumbPhysicalPath) && (ext == ".png" || ext == ".jpg" || ext == ".jpeg"))
                {
                    using var image = Image.Load(physicalPath);
                    image.Mutate(x => x.AutoOrient());
                    image.Mutate(x => x.Resize(resizeOptions));
                    image.Save(thumbPhysicalPath, new WebpEncoder());
                }

                if (System.IO.File.Exists(thumbPhysicalPath))
                {
                    return new PhysicalFileResult(thumbPhysicalPath, MimeTypeMap.GetMimeType(".webp"));
                }

                return new PhysicalFileResult(physicalPath, MimeTypeMap.GetMimeType(ext));
            }
            catch (Exception)
            {
                return NotFound();
            }
        }

    }
}
