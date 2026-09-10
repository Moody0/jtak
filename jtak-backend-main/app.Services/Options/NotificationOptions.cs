namespace App.Shared.Services.Options
{
    public class NotificationOptions
    {
        // SMS / Twillio
        public string TwilioMobile { get; set; }
        public string TwilioAuthToken { get; set; }
        public string TwilioAccountSid { get; set; }

        // User topic Notification Salt
        public string UserTopicSalt { get; set; }
    }
}
