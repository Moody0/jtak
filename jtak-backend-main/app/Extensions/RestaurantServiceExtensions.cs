using DamienG.Security.Cryptography;
using System;
using System.Security.Cryptography;

namespace App.Extensions
{
    public static class RestaurantServiceExtensions
    {
        public static string GetToken(int Id)
        {
            var dailyBytes = BitConverter.GetBytes(DateTime.Now.Date.Ticks + Id);
            using (var md5 = MD5.Create())
            {
                return (Crc32.Compute(md5.ComputeHash(dailyBytes)) % 1000000).ToString("D6");
            }
        }
    }
}
