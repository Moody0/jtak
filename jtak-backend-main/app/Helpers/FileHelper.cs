using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats.Jpeg;
using SixLabors.ImageSharp.Formats.Png;
using SixLabors.ImageSharp.Processing;
using Solf.Helpers;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Threading.Tasks;

namespace App.Helpers
{
    public static class FileHelper
    {
        public enum FileTypesAllowed
        {
            All = 0,
            Pdf = 1,
            Image = 2
        }

        public static string GeneratNewToken(this IWebHostEnvironment env, string ext)
        {
            var fileId = Guid.NewGuid().ToString("N");
            var timestamp = DateTime.UtcNow;

            var fileNamewithExtension = fileId + ext;

            var dbField = $"{timestamp.Year}_{timestamp.Month}_{timestamp.Day}_{fileNamewithExtension}";

            var physicalPath = env.GetPhysicalPath(dbField);
            var directory = Path.GetDirectoryName(physicalPath);

            if (!Directory.Exists(directory)) Directory.CreateDirectory(directory);
            return dbField;
        }
        public static string GetPhysicalPath(this IWebHostEnvironment env, string token)
        {
            var fileCenterPath = env.ContentRootPath + SiteOptions.FileCenterPath.Replace("/", "\\");
            try
            {
                var directFile = Path.Combine(fileCenterPath, token);
                if (token.Count(x => x == '_') < 3) return directFile;
                var parts = token.Split('_');
                var directory = Path.Combine(fileCenterPath, parts[0], parts[1], parts[2]);
                var fileNamewithExtension = parts[3];

                //Check File Path nd create if not exist
                if (!Directory.Exists(directory)) Directory.CreateDirectory(directory);

                //Get Full Virtual And Physical Paths
                var fullPhysicalPath = Path.Combine(directory, fileNamewithExtension);
                return fullPhysicalPath;
            }
            catch (Exception)
            {
                return $"{fileCenterPath}\\";
            }
        }
        public static string GetVirtualPath(string dbField)
        {
            try
            {
                var parts = dbField.Split('_');
                var fullVirtualPath = $"~{SiteOptions.FileCenterPath}/{parts[0]}/{parts[1]}/{parts[2]}/{parts[3]}";
                return fullVirtualPath;
            }
            catch (Exception)
            {
                return $"{SiteOptions.FileCenterPath}/";
            }
        }

        /// <summary>
        /// returns NULL if no file saved
        /// </summary>
        /// <returns></returns>
        public static async Task<string> SaveFile(this IWebHostEnvironment env, IFormFile fileUpload, FileTypesAllowed fileTypesAllowed = FileTypesAllowed.All, int rotate = 0)
        {
            if (fileUpload == null)
                return null;

            var ext = Path.GetExtension(fileUpload.FileName);
            var token = env.GeneratNewToken(ext);
            var fullPhysicalPath = env.GetPhysicalPath(token);

            // todo throw customException if file extensions not allowed
            if (!IsValidExt(fileTypesAllowed, ext))
                return null;

            if (rotate == 0)
            {
                using var fileStream = new FileStream(fullPhysicalPath, FileMode.Create);
                await fileUpload.CopyToAsync(fileStream);
            }
            else
            {
                using var image = Image.Load(fileUpload.OpenReadStream());
                image.Mutate(x => x.Rotate(rotate));
                if (ext == ".png")
                {
                    image.Save(fullPhysicalPath, new PngEncoder());
                }
                else
                {
                    image.Save(fullPhysicalPath, new JpegEncoder());
                }
            }

            return File.Exists(fullPhysicalPath) ? token : null;
        }
        /// <summary>
        /// returns NULL if no file saved
        /// </summary>
        /// <returns></returns>
        public static async Task<string> SaveFile(this IWebHostEnvironment env, IFormFile[] fileuploads, FileTypesAllowed fileTypesAllowed = FileTypesAllowed.All, int rotate = 0)
        {
            if (fileuploads == null)
                return null;

            var dbField = new List<string>();

            foreach (var fileupload in fileuploads)
            {
                dbField.Add(await env.SaveFile(fileupload, fileTypesAllowed, rotate));
            }
            dbField = dbField.Where(x => !string.IsNullOrEmpty(x)).ToList();

            return dbField.Any() ? string.Join(",", dbField) : null;
        }


        public static string SaveFile(this IWebHostEnvironment env, string file, FileTypesAllowed fileTypesAllowed = FileTypesAllowed.All, bool deleteWhenDone = false)
        {
            if (file == null)
                return null;

            var ext = Path.GetExtension(file);
            var token = env.GeneratNewToken(ext);
            var fullPhysicalPath = env.GetPhysicalPath(token);

            if (!IsValidExt(fileTypesAllowed, ext))
                return null;
            File.Copy(file, fullPhysicalPath);
            if (deleteWhenDone)
            {
                File.Delete(file);
            }

            return File.Exists(fullPhysicalPath) ? token : null;
        }
        /// <summary>
        /// returns NULL if no file saved
        /// </summary>
        /// <returns></returns>
        public static string SaveFile(this IWebHostEnvironment env, string[] files, FileTypesAllowed fileTypesAllowed = FileTypesAllowed.All)
        {
            if (files == null)
                return null;

            var dbField = new List<string>();

            foreach (var file in files)
            {
                dbField.Add(env.SaveFile(file, fileTypesAllowed));
            }
            dbField = dbField.Where(x => !string.IsNullOrEmpty(x)).ToList();

            return dbField.Any() ? string.Join(",", dbField) : null;
        }
        /// <summary>
        /// returns NULL if no file saved
        /// </summary>
        /// <returns></returns>
        public static async Task<string> SaveFileFromUrl(this IWebHostEnvironment env, string[] urls, FileTypesAllowed fileTypesAllowed = FileTypesAllowed.All)
        {
            if (urls == null) return null;

            var dbField = new List<string>();

            foreach (var url in urls)
            {
                var token = await env.SaveFileFromUrl(url);
                dbField.Add(token);
            }

            return dbField.Any() ? string.Join(",", dbField) : null;
        }
        public static async Task<string> SaveFileFromUrl(this IWebHostEnvironment env, string url, FileTypesAllowed fileTypesAllowed = FileTypesAllowed.All)
        {
            if (url == null) return null;

            using (var client = new HttpClient())
            {
                var response = await client.GetAsync(url);
                var contentType = response.Content.Headers.ContentType.MediaType;
                var ext = MimeTypeMap.GetExtension(contentType);

                if (!response.IsSuccessStatusCode) return null;
                if (!IsValidExt(fileTypesAllowed, ext))
                    return null;
                var data = await response.Content.ReadAsByteArrayAsync();
                var token = env.SaveFile(data, ext);
                return token;
            }
        }
        public static string SaveFile(this IWebHostEnvironment env, byte[] data, string ext)
        {
            if (data == null) return null;

            var token = env.GeneratNewToken(ext);
            var fullPhysicalPath = env.GetPhysicalPath(token);

            File.WriteAllBytes(fullPhysicalPath, data);
            return File.Exists(fullPhysicalPath) ? token : null;
        }
        public static void DeleteFile(this IWebHostEnvironment env, string fid)
        {
            var fullPhysicalPath = env.GetPhysicalPath(fid);
            if (File.Exists(fullPhysicalPath))
                File.Delete(fullPhysicalPath);
        }
        public static string SmartSaveImage(this IWebHostEnvironment env, byte[] data, string ext = ".jpg")
        {
            if (data == null)
                return null;

            var token = env.GeneratNewToken(ext);
            var fullPhysicalPath = env.GetPhysicalPath(token);

            using (var image = Image.Load(data))
            {
                if (ext == ".png")
                {
                    image.Save(fullPhysicalPath, new PngEncoder());
                }
                else
                {
                    image.Save(fullPhysicalPath, new JpegEncoder());
                }
            }
            return File.Exists(fullPhysicalPath) ? token : null;
        }
        public static long GetBytesCount(this IWebHostEnvironment env, string dbField)
        {
            try
            {
                var ppath = GetPhysicalPath(env, dbField);
                return new FileInfo(ppath).Length;
            }
            catch
            {
                return 0;
            }
        }

        private static bool IsValidExt(FileTypesAllowed type, string ext)
        {
            var imageExts = new[] { ".png", ".jpg", ".jpeg" };
            var pdfExts = new[] { ".pdf" };

            return type == FileTypesAllowed.All ||
                  (type == FileTypesAllowed.Image && imageExts.Contains(ext)) ||
                  (type == FileTypesAllowed.Pdf && pdfExts.Contains(ext));
        }

        /*
        public static List<string> ListImageUrls(string dbFieldSignleOrMultiple, int w = 0, int h = 0)
        {
            if (dbFieldSignleOrMultiple.IsNullOrEmpty()) return new List<string>();

            return dbFieldSignleOrMultiple.Split().Select(x => FileHelper.Render(x).ImgHref(w, h)).ToList();
        }*/
    }
}
