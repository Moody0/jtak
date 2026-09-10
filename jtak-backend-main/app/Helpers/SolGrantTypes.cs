using System;

namespace App.Helpers
{
    public static class SolGrantTypes
    {
        public const string GoogleGrantTypeWeb = "sol:google_identity_token:web";
        public const string GoogleGrantTypeiOS = "sol:google_identity_token:ios";
        public const string GoogleGrantTypeAndroid = "sol:google_identity_token:android";

        public const string FacebookGrantType = "sol:facebook_access_token";

        public const string InstagramGrantType = "sol:instagram_identity_token";

        public const string AppleGrantType = "sol:apple_identity_token";

        public const string SayPlatformGrantType = "sol:sayplatform_token";

        public const string SMSCodeGrantType = "sol:sms_code";

        public static bool IsValid(string solGrantType) =>
            solGrantType == GoogleGrantTypeWeb ||
            solGrantType == GoogleGrantTypeiOS ||
            solGrantType == GoogleGrantTypeAndroid ||
            solGrantType == FacebookGrantType ||
            solGrantType == InstagramGrantType ||
            solGrantType == AppleGrantType ||
            solGrantType == SMSCodeGrantType ||
            solGrantType == SayPlatformGrantType;
        public static string GetProvider(string solGrantType) =>
            solGrantType switch
            {
                GoogleGrantTypeWeb => "Google",
                GoogleGrantTypeiOS => "Google",
                GoogleGrantTypeAndroid => "Google",
                FacebookGrantType => "Facebook",
                InstagramGrantType => "Instagram",
                AppleGrantType => "Apple",
                SMSCodeGrantType => "Phone",
                SayPlatformGrantType => "SayPlatform",
                _ => throw new NotImplementedException()
            };
    }
}
