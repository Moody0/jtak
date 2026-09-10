using System.Linq;

namespace App.Shared.Services.Options
{
    public class OAuthOptions
    {
        public string WebClientSecret { get; set; }
        public string WebClientId { get; set; }
        public string AndroidClientId { get; set; }
        public string iOSClientId { get; set; }

        public string ClientId(string grantType)
        {
            var grantedFor = grantType?.Split(":").LastOrDefault();
            return grantedFor == "ios" ? iOSClientId : grantedFor == "android" ? AndroidClientId : WebClientId;
        }
    }

    public class FacebookAuthOptions
    {
        public string AppId { get; set; }
        public string AppSecret { get; set; }
    }
    public class InstagramAuthOptions : OAuthOptions
    {
    }
    public class GoogleAuthOptions : OAuthOptions
    {
    }
}