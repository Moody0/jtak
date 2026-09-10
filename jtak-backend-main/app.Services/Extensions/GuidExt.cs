using System;
using System.Security.Cryptography;
using System.Text;

namespace App.Shared.Services.Extentions
{
    public static class GuidExt
    {
        public static Guid FromString(string input)
        {
            using var md5 = MD5.Create();
            var hash = md5.ComputeHash(Encoding.UTF8.GetBytes(input));
            return new Guid(hash);
        }
    }
}
