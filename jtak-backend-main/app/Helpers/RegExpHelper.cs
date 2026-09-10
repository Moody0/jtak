using System.Text.RegularExpressions;

namespace App.Helpers
{
    public static class RegExpHelper
    {
        public const string Email = @"^\w+([-+.']\w+)*@\w+([-.]\w+)*\.\w+([-.]\w+)*$";
        public const string UserName = @"^[a-zA-Z0-9-]+$";
        public const string DisplayName = @"^([ء-ي]|[a-z]|[A-Z]|\s)*$";

        /// <summary>
        /// Example : 0555777888
        /// </summary>
        public const string SaudiMobile = @"^(05)[0-9]{8}$";

        /// <summary>
        /// Example : 0123456789
        /// </summary>
        public const string SaudiTelephone = @"^(01)[0-9]{8}$";

        /// <summary>
        /// Example : 6540564064056405640654
        /// </summary>
        public const string PositiveNumber = @"^[0-9]*$";

        /// <summary>
        /// Example 8949498498.22
        /// </summary>
        public const string FloatWithTwoDigitAfterPoint = @"^\d+(\.\d{1,2})?$";

        /// <summary>
        /// Example : http://www.google.com https://google.com
        /// </summary>
        public const string Url = @"^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$";

        /// <summary>
        /// Example : dd/MM/yyyy
        /// </summary>
        public const string Date = @"^([0]?[0-9]|[12][0-9]|[3][01])[./-]([0]?[1-9]|[1][0-2])[./-]([0-9]{4}|[0-9]{2})$";

        //public const string ArEnSpace = @"^([ء-ي]|[a-z]|[A-Z]|\s)*$";
        //public const string CharDigitSpace = @"^([ء-ي]|[a-z]|[A-Z]|\s)*$";
        //public const string DisplayName = @"^([ء-يa-zA-Z_-]|\s)+$";
        //public const string Slugan = @"^[a-z0-9-]+$";

        //Generic Method
        public static bool IsValid(string exp, string input)
        {
            return new Regex(exp).IsMatch(input);
        }

        //Customized Methods
        public static bool IsEmail(string input) => !string.IsNullOrEmpty(input) && new Regex(Email).IsMatch(input);
        public static bool IsMobile(string input) => !string.IsNullOrEmpty(input) && new Regex(SaudiMobile).IsMatch(input);
        public static bool IsLandline(string input) => !string.IsNullOrEmpty(input) && new Regex(SaudiTelephone).IsMatch(input);
    }
}
