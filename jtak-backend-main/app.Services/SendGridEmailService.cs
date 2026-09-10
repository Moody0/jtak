using App.Shared.Services.Helpers;
using App.Shared.Services.Options;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using SendGrid;
using SendGrid.Helpers.Mail;
using Solf.Services;
using System;
using System.Linq;
using System.Threading.Tasks;

namespace App.Shared.Services
{
    public class SendGridEmailService : IEmailService
    {
        private ILogger<SendGridEmailService> _logger { get; set; }
        private SendGridOptions Options { get; } //set only via Secret Manager

        public SendGridEmailService(IOptions<SendGridOptions> options, ILogger<SendGridEmailService> logger)
        {
            Options = options.Value;
            _logger = logger;
        }

        public async Task<object> SendAsync(SolEmailMessage message, params string[] recipientEmails)
        {
            if (recipientEmails == null || !recipientEmails.Any())
            {
                _logger.LogError("Can't send email: No recipients where specified!");
                return false;
            }
            var client = new SendGridClient(Options.SendGridKey);
            var msg = new SendGridMessage()
            {
                From = new EmailAddress(message.FromEmail, message.FromName),
                Subject = message.Subject,
                PlainTextContent = message.BodyPlain,
                HtmlContent = message.BodyHtml
            };
            foreach (var recipientEmail in recipientEmails)
                msg.AddTo(new EmailAddress(recipientEmail));

            try
            {
                return await client.SendEmailAsync(msg);
            }
            catch (Exception e)
            {
                _logger.LogError("Can't send email: SendGrid Client Failed with exception:" + e);
                return false;
            }
        }

        public SolEmailMessage Create(string subject, string body, string link = null, string linkText = null, string lang = null, string template = "default") =>
            new()
            {
                FromEmail = Options.SendGridEmail,
                FromName = Options.SendGridEmail,
                BodyHtml = GetBody(subject, body, link, linkText),
                BodyPlain = GetPlainTextBody(body),
                Subject = GetSubject(subject)
            };

        private static string PlatformName => "Strategos - استراتيجوس";
        private static string GetSubject(string subject) => $"{subject} | {PlatformName}";
        private static string GetBody(string subject, string innterBody, string link = null, string linkText = "هذا الرابط") =>
            @$"<div style=""direction:rtl;max-width :500px;margin:auto;text-align:center;box-shadow: 0 4px 8px 0 rgba(0,0,0,0.2);padding:15px;"">
                   <img src=""{AppDomainHelper.ApiUrl}/images/logodark.png"" style=""padding-top:5px;margin:auto;height:100px;"" />
                   <hr />
                   <h2 style=""text-align:center;width:100%;"">{subject}</h2>
                   {innterBody}
                   {(!string.IsNullOrEmpty(link) ? $"<a target=\"_blank\" href=\"{link}\">{linkText}</a>" : "")}
                    <p>
                    لأي استفسار لا تتردوا بمراسلتنا على: <a href=""mailto:help@onstrategos.com"">help@onstrategos.com</a><br/>
                    دمتم بخير<br/>
                    فريق استراتيجوس
               </div>";

        private static string GetPlainTextBody(string innterBody, string url = null, string btnText = "هذا الرابط") =>
            @$"{innterBody}
            {(!string.IsNullOrEmpty(url) ? $"{btnText}: {url}" : "")}
            دمتم بخير
            فريق استراتيجوس
            ";
    }
}
