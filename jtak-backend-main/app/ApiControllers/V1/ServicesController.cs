
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
using Microsoft.EntityFrameworkCore;
using App.Shared.Entities.Enums;

namespace App.ApiControllers.V1
{
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
    [ApiController]
    [Route("api/v{version:apiVersion}/[controller]")]
    [ApiVersion("1")]
    public class ServicesController : SolBaseController
    {
        private readonly IWebHostEnvironment _env;
        private readonly AppDbContext _app;
        public ServicesController(IAppUnitOfWork UOW,
                                    ILogger<ServicesController> logger,
                                    UserManager<AppUser> userManager,
                                    IMapper mapper,
                                    IWebHostEnvironment env,
                                    AppDbContext app) : base(UOW, mapper, logger, userManager)
        {
            _env = env;
            _app = app;
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
        public async Task<IActionResult> Download(string id, string token = "")
        {
            if (id != null && (id.StartsWith("http://", StringComparison.OrdinalIgnoreCase) || id.StartsWith("https://", StringComparison.OrdinalIgnoreCase)))
            {
                return Redirect(id);
            }
            if (!IsSafeFileToken(id) || await IsPrivateReceipt(id)) return NotFound();
            try
            {
                var fullPath = FileHelper.GetPhysicalPath(_env, id);
                if (!System.IO.File.Exists(fullPath)) return NotFound();
                var ext = Path.GetExtension(id)?.ToLower() ?? "";

                return new PhysicalFileResult(fullPath, MimeTypeMap.GetMimeType(ext));
            }
            catch (Exception e)
            {
                return NotFound();
            }
        }

        [HttpGet("DiagFileCenter")]
        [AllowAnonymous]
        public IActionResult DiagFileCenter()
        {
            var result = new System.Collections.Generic.Dictionary<string, object>();
            result["ContentRootPath"] = _env.ContentRootPath;
            result["WebRootPath"] = _env.WebRootPath;
            var fileCenter = _env.ContentRootPath + SiteOptions.FileCenterPath.Replace("/", "\\");
            result["FileCenterExpected"] = fileCenter;
            result["FileCenterExists"] = Directory.Exists(fileCenter);
            if (Directory.Exists(fileCenter))
            {
                result["FileCenterDirectories"] = Directory.GetDirectories(fileCenter).Select(Path.GetFileName).ToArray();
                result["FileCenterFilesCount"] = Directory.GetFiles(fileCenter).Length;
                result["FileCenterSampleFiles"] = Directory.GetFiles(fileCenter).Take(10).Select(Path.GetFileName).ToArray();
            }
            var parentFileCenter = Path.GetFullPath(Path.Combine(_env.ContentRootPath, "..", "FileCenter"));
            result["ParentFileCenter"] = parentFileCenter;
            result["ParentFileCenterExists"] = Directory.Exists(parentFileCenter);
            if (Directory.Exists(parentFileCenter))
            {
                result["ParentFileCenterDirectories"] = Directory.GetDirectories(parentFileCenter).Select(Path.GetFileName).ToArray();
                result["ParentFileCenterFilesCount"] = Directory.GetFiles(parentFileCenter).Length;
                result["ParentFileCenterSampleFiles"] = Directory.GetFiles(parentFileCenter).Take(10).Select(Path.GetFileName).ToArray();
            }
            var testBarcode = "6210210355461.png";
            result["TestBarcodePath"] = FileHelper.GetPhysicalPath(_env, testBarcode);
            result["TestBarcodeExists"] = System.IO.File.Exists(FileHelper.GetPhysicalPath(_env, testBarcode));
            return Ok(result);
        }

        // Receipts are internal accounting evidence. Never serve them through
        // anonymous media routes, even if a customer retained an old token.
        [HttpGet("ErrandReceipt/{id:int}")]
        [Authorize(Policy = App.Helpers.Authorization.DashboardAccessService.Policy)]
        public async Task<IActionResult> ErrandReceipt(int id)
        {
            var receiptToken = await _app.SupportMessages.AsNoTracking()
                .Where(x => x.Id == id && x.ErrandStatus != null)
                .Select(x => x.ErrandReceiptPhotoToken).FirstOrDefaultAsync();
            if (!IsSafeFileToken(receiptToken)) return NotFound();
            var path = _env.GetPhysicalPath(receiptToken);
            if (!System.IO.File.Exists(path)) return NotFound();
            Response.Headers["Cache-Control"] = "private, no-store";
            return new PhysicalFileResult(path, MimeTypeMap.GetMimeType(Path.GetExtension(receiptToken)));
        }

        private static bool IsSafeFileToken(string id) => !string.IsNullOrWhiteSpace(id) &&
            id.All(c => char.IsAsciiLetterOrDigit(c) || c == '_' || c == '-' || c == '.') &&
            !id.Contains("..");

        private Task<bool> IsPrivateReceipt(string id)
        {
            var parts = id.Split('_');
            // Include old generated thumbnails and tokens with extra suffixes:
            // FileHelper resolves them to the same stored file or its preview.
            var prefix = parts.Length >= 4 && parts[3].Length >= 32 &&
                Guid.TryParseExact(parts[3].Substring(0, 32), "N", out _)
                ? string.Join("_", parts.Take(3)) + "_" + parts[3].Substring(0, 32)
                : id;
            return _app.SupportMessages.AsNoTracking().AnyAsync(x =>
                x.ErrandReceiptPhotoToken != null && x.ErrandReceiptPhotoToken.StartsWith(prefix));
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
        public async Task<IActionResult> PreviewImageApi(string id = "", int w = 150, int h = 150, bool crop = true)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(id)) return NotFound();

                var cleanId = id.Split(',')[0].Trim();
                if (cleanId.StartsWith("http://", StringComparison.OrdinalIgnoreCase) || cleanId.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
                {
                    return Redirect(cleanId);
                }
                if (!IsSafeFileToken(cleanId) || await IsPrivateReceipt(cleanId)) return NotFound();
                var physicalPath = FileHelper.GetPhysicalPath(_env, cleanId);
                var ext = Path.GetExtension(cleanId)?.ToLower() ?? "";

                bool isDefaultImage = false;
                if (!System.IO.File.Exists(physicalPath))
                {
                    physicalPath = Path.Combine(_env.WebRootPath, "images", "default-image.jpg");
                    ext = ".jpg";
                    if (!System.IO.File.Exists(physicalPath))
                    {
                        return NotFound();
                    }
                    isDefaultImage = true;

                    // The product fallback image can be replaced by a newer
                    // branded asset. Prevent clients and proxies from keeping
                    // the previous generic fallback under the same image URL.
                    Response.Headers["Cache-Control"] = "no-store, no-cache, must-revalidate";
                    Response.Headers["Pragma"] = "no-cache";
                    Response.Headers["Expires"] = "0";
                }

                if (ext == ".svg" || ext == ".webp" || ext == ".gif" || ext == ".avif")
                {
                    return new PhysicalFileResult(physicalPath, MimeTypeMap.GetMimeType(ext));
                }

                string thumbPhysicalPath;
                if (isDefaultImage)
                {
                    var imageVersion = System.IO.File.GetLastWriteTimeUtc(physicalPath).Ticks;
                    thumbPhysicalPath = Path.Combine(_env.WebRootPath, "images", $"default-image_{imageVersion}_{w}x{h}{(crop ? "c" : "")}.webp");
                }
                else
                {
                    var cleanNameWithoutExt = Path.GetFileNameWithoutExtension(cleanId);
                    var dir = Path.GetDirectoryName(physicalPath) ?? Path.Combine(_env.ContentRootPath, "FileCenter");
                    thumbPhysicalPath = Path.Combine(dir, $"{cleanNameWithoutExt}_{w}x{h}{(crop ? "c" : "")}.webp");
                }
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
