namespace App.Services.Model
{
    public class NotificationOptions
    {
        // Emails / SendGrid
        public string SendGridKey { get; set; }
        public string SendGridEmail { get; set; }
        public string SendGridDisplayname { get; set; }

        // SMS / Twillio
        public string TwilioMobile { get; set; }
        public string TwilioAuthToken { get; set; }
        public string TwilioAccountSid { get; set; }

        // User topic Notification Salt
        public string UserTopicSalt { get; set; }
    }
}
