using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats.Jpeg;
using SixLabors.ImageSharp.Processing;
using System.IO;

namespace App.Helpers
{
    public static class ImageHelper
    {
        public static byte[] ResizeImage(string path, int w = 150, int h = 150, bool crop = true, string ext = ".jpg")
        {
            var resizeOptions = new ResizeOptions { Size = new Size(w, h), Mode = crop ? ResizeMode.Crop : ResizeMode.Max };

            using (var image = Image.Load(path))
            {
                image.Mutate(x => x.Resize(resizeOptions));

                //var result = MemoryMarshal.AsBytes(image.GetPixelSpan()).ToArray();using (var ms = new MemoryStream())
                using (var ms = new MemoryStream())
                {
                    if (ext == ".png")
                    {
                        image.SaveAsPng(ms);
                    }
                    else
                    {
                        image.SaveAsJpeg(ms);
                    }
                    return ms.ToArray();
                }
            }
        }
        public static byte[] ResizeImage(byte[] data, int w = 150, int h = 150, bool crop = true, string ext = ".jpg")
        {
            var resizeOptions = new ResizeOptions { Size = new Size(w, h), Mode = crop ? ResizeMode.Crop : ResizeMode.Max };

            using (var image = Image.Load(data))
            {
                image.Mutate(x => x.Resize(resizeOptions));

                //var result = MemoryMarshal.AsBytes(image.GetPixelSpan()).ToArray();using (var ms = new MemoryStream())
                using (var ms = new MemoryStream())
                {
                    if (ext == ".png")
                    {
                        image.SaveAsPng(ms);
                    }
                    else
                    {
                        image.SaveAsJpeg(ms);
                    }
                    return ms.ToArray();
                }
            }
        }
        public static byte[] ToJpeg(byte[] data)
        {
            using (var image = Image.Load(data))
            {
                using (var ms = new MemoryStream())
                {
                    image.SaveAsJpeg(ms, new JpegEncoder());
                    return ms.ToArray();
                }
            }
        }
    }
}
