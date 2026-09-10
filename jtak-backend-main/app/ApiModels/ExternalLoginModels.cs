using System.Text.Json.Serialization;

namespace App.ApiModels
{
    class InstagramRootData
    {
        public InstagramUserInfo data { get; set; }
    }
    public class InstagramUserInfo
    {
        [JsonPropertyName("id")]
        public string Id { get; set; }
        [JsonPropertyName("username")]
        public string Username { get; set; }
        [JsonPropertyName("full_name")]
        public string FullName { get; set; }
        [JsonPropertyName("profile_picture")]
        public string ProfilePicture { get; set; }
        [JsonPropertyName("bio")]
        public string Bio { get; set; }
        [JsonPropertyName("website")]
        public string Website { get; set; }
        [JsonPropertyName("is_business")]
        public bool IsBusiness { get; set; }
    }

    class GoogleUserInfo
    {
        // These six fields are included in all Google ID Tokens.
        [JsonPropertyName("iss")]
        public string Issuer { get; set; }

        [JsonPropertyName("sub")]
        public string Id { get; set; }

        [JsonPropertyName("azp")]
        public string azp { get; set; }

        [JsonPropertyName("aud")]
        public string ClientId { get; set; }

        [JsonPropertyName("iat")]
        public string iat { get; set; }

        [JsonPropertyName("exp")]
        public string Expiry { get; set; }

        // These seven fields are only included when the user has granted the "profile" and "email" OAuth scopes to the application.
        [JsonPropertyName("email")]
        public string Email { get; set; }

        [JsonPropertyName("email_verified")]
        public bool EmailVerified { get; set; }

        [JsonPropertyName("name")]
        public string Name { get; set; }
        [JsonPropertyName("picture")]
        public string Picture { get; set; }

        [JsonPropertyName("given_name")]
        public string GivenName { get; set; }

        [JsonPropertyName("family_name")]
        public string FamilyName { get; set; }

        [JsonPropertyName("locale")]
        public string Lang { get; set; }
    }
    class FacebookUserInfo
    {
        public long Id { get; set; }
        public string Email { get; set; }
        public string Name { get; set; }
        [JsonPropertyName("first_name")]
        public string FirstName { get; set; }
        [JsonPropertyName("last_name")]
        public string LastName { get; set; }
        public string Gender { get; set; }
        public string Locale { get; set; }
        public FacebookPictureData Picture { get; set; }
    }

    class FacebookPictureData
    {
        public FacebookPicture Data { get; set; }
    }

    class FacebookPicture
    {
        public int Height { get; set; }
        public int Width { get; set; }
        [JsonPropertyName("is_silhouette")]
        public bool IsSilhouette { get; set; }
        public string Url { get; set; }
    }

    class FBAccessTokenData
    {
        [JsonPropertyName("app_id")]
        public long AppId { get; set; }
        public string Type { get; set; }
        public string Application { get; set; }
        [JsonPropertyName("expires_at")]
        public long ExpiresAt { get; set; }
        [JsonPropertyName("is_valid")]
        public bool IsValid { get; set; }
        [JsonPropertyName("user_id")]
        public long UserId { get; set; }
    }

    class FBAccessTokenValidation
    {
        public FBAccessTokenData Data { get; set; }
    }

    class FBAppAccessToken
    {
        [JsonPropertyName("token_type")]
        public string TokenType { get; set; }
        [JsonPropertyName("access_token")]
        public string AccessToken { get; set; }
    }

    class SayUserInfo
    {
        // These six fields are included in all Google ID Tokens.
        [JsonPropertyName("iss")]
        public string Issuer { get; set; }

        [JsonPropertyName("sub")]
        public string Id { get; set; }

        [JsonPropertyName("azp")]
        public string azp { get; set; }

        [JsonPropertyName("aud")]
        public string ClientId { get; set; }

        [JsonPropertyName("iat")]
        public string iat { get; set; }

        [JsonPropertyName("exp")]
        public string Expiry { get; set; }

        // These seven fields are only included when the user has granted the "profile" and "email" OAuth scopes to the application.
        [JsonPropertyName("email")]
        public string Email { get; set; }

        [JsonPropertyName("email_verified")]
        public bool EmailVerified { get; set; }

        [JsonPropertyName("fullName")]
        public string Name { get; set; }

        [JsonPropertyName("picture")]
        public string Picture { get; set; }

        [JsonPropertyName("given_name")]
        public string GivenName { get; set; }

        [JsonPropertyName("family_name")]
        public string FamilyName { get; set; }

        [JsonPropertyName("locale")]
        public string Lang { get; set; }
    }


    class UserInfo
    {
        // These six fields are included in all Google ID Tokens.
        [JsonPropertyName("iss")]
        public string Issuer { get; set; }

        [JsonPropertyName("sub")]
        public string Id { get; set; }

        [JsonPropertyName("azp")]
        public string azp { get; set; }

        [JsonPropertyName("aud")]
        public string ClientId { get; set; }

        [JsonPropertyName("iat")]
        public string iat { get; set; }

        [JsonPropertyName("exp")]
        public string Expiry { get; set; }

        [JsonPropertyName("email")]
        public string Email { get; set; }

        [JsonPropertyName("name")]
        public string Name { get; set; }

        [JsonPropertyName("picture")]
        public string Picture { get; set; }
    }
}