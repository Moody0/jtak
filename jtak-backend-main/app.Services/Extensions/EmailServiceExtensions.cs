using App.Shared.Services.Helpers;
using App.Shared.Entities;
using Solf.Services;
using System.Threading.Tasks;

namespace App.Shared.Services.Extentions
{
    public static class EmailServiceExtensions
    {
        public static async Task SendContactMessage(this IEmailService service, string displayName, string title, string email, string msg, AppUser user, string phone = null)
        {
            var subject = $"{title} - Message from: '{displayName}' / contact form";
            var body = $@"<p>Message from: '{displayName}</p>'
                          <p>Phone: {phone}</p>
                          <p>Email: {email}</p>
                          <p>Message: {msg}</p> 
                          <hr>
                          {(user != null ? $"<p>#uid:{user?.Id} ({user?.FirstName} {user?.LastName})</p>" : "")}";

            await service.SendAsync(service.Create(subject, body, AppDomainHelper.InfoEmail));
        }


        public static async Task SendEmailConfirmationAsync(this IEmailService service, string userDisplayName, string email, string callbackUrl)
        {
            var subject = $"فعل بريدك الإلكتروني";
            var body = $@" السيد/ة<b> {userDisplayName},</b><br/><br/>
                            يرجى فتح الرابط التالي لتفعيل بريدك الإلكتروني (<a href=""{AppDomainHelper.BaseUrl}/{callbackUrl}"">فعل البريد الإلكتروني!</a>).<br/>";

            await service.SendAsync(service.Create(subject, body, email));
        }
        public static async Task SendEmailChangedConfirmationAsync(this IEmailService service, string userDisplayName, string oldEmail, string newEmail, string callbackUrl)
        {
            var subject = $"لقد تم تغيير بريدك الإلكتروني";
            var body = $@" السيد/ة<b> {userDisplayName},</b><br/><br/>
                            يرجى فتح الرابط التالي لتفعيل بريدك الإلكتروني الجديد (<a href=""{AppDomainHelper.BaseUrl}/{callbackUrl}"">فعل البريد الإلكتروني!</a>).<br/>";
            await service.SendAsync(service.Create(subject, body, newEmail));
        }
        public static async Task SendPasswordResetTokenAsync(this IEmailService service, string userDisplayName, string email, string callbackUrl)
        {
            var subject = $"تغيير كلمة السر الخاصة بك";
            var body = $@" السيد/ة<b> {userDisplayName}،</b><br/><br/>
                        يرجى فتح الرابط التالي لتغيير كلمة السر الخاصة بك <a href=""{AppDomainHelper.FrontEndUrl}/{callbackUrl}"">تغيير كلمة السر!</a>";

            await service.SendAsync(service.Create(subject, body, email));
        }

        public static async Task SendEmailChangeLinkAsync(this IEmailService service, string userDisplayName, string oldEmail, string newEmail, string callbackUrl)
        {
            var subject = $"تغيير بريدك الإلكتروني";
            var body = $@" السيد/ة<b> {userDisplayName}،</b><br/><br/>
                            سيتم تغيير بريدك الإلكتروني من {oldEmail}  إلى {newEmail}<br/>
                            يرجى فتح الرابط التالي لتأكيد تغيير بريدك الإلكتروني (<a href=""{AppDomainHelper.FrontEndUrl}/{callbackUrl}"">فعل البريد الإلكتروني الجديد!</a>).<br/>";
            await service.SendAsync(service.Create(subject, body, newEmail));
        }
        public static async Task ReSendEmailChangeLinkAsync(this IEmailService service, string userDisplayName, string oldEmail, string newEmail, string callbackUrl)
        {
            var subject = $"تغيير بريدك الإلكتروني";
            var body = $@" السيد/ة<b> {userDisplayName}،</b><br/><br/>
                            سيتم تغيير بريدك الإلكتروني من {oldEmail}  إلى {newEmail}<br/>
                            يرجى فتح الرابط التالي لتأكيد تغيير بريدك الإلكتروني (<a href=""{AppDomainHelper.FrontEndUrl}/{callbackUrl}"">فعل البريد الإلكتروني الجديد!</a>).<br/>";
            await service.SendAsync(service.Create(subject, body, newEmail));
        }
        public static async Task SendEmailChangedConfirmationAsync(this IEmailService service, string userDisplayName, string oldEmail, string newEmail)
        {
            var subject = $"لقد تم تغيير بريدك الإلكتروني";
            var body = $@" السيد/ة<b> {userDisplayName}،</b><br/><br/>
                            لقد تم تغيير بريدك الإلكتروني من {oldEmail}  إلى {newEmail}<br/>.";
            await service.SendAsync(service.Create(subject, body, newEmail));
        }

        /************************************************************************************************************************/
    }
}
