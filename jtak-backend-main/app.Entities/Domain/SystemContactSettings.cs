using System;

namespace App.Shared.Entities.Domain
{
    /// <summary>
    /// Centralized system-wide contact information and social media links.
    /// Used across Customer, Delivery, Merchant apps, web, and Admin dashboard.
    /// </summary>
    public class SystemContactSettings
    {
        public const string Key = "SystemContactSettings";

        /// <summary>
        /// Local phone number for hotline calls (e.g., "0985615705").
        /// </summary>
        public string PhoneNumber { get; set; } = "0985615705";

        /// <summary>
        /// International phone number for dialer links (e.g., "+963985615705").
        /// </summary>
        public string PhoneInternational { get; set; } = "+963985615705";

        /// <summary>
        /// Human-readable formatted phone number (e.g., "0985 615 705").
        /// </summary>
        public string PhoneFormatted { get; set; } = "0985 615 705";

        /// <summary>
        /// WhatsApp digits without plus or special chars (e.g., "963985615705").
        /// </summary>
        public string WhatsAppNumber { get; set; } = "963985615705";

        /// <summary>
        /// Official customer support email (e.g., "contact@jtak.app").
        /// </summary>
        public string SupportEmail { get; set; } = "contact@jtak.app";

        /// <summary>
        /// Official Facebook page URL.
        /// </summary>
        public string FacebookUrl { get; set; } = "https://www.facebook.com/app.jtak/";

        /// <summary>
        /// Official Instagram profile URL.
        /// </summary>
        public string InstagramUrl { get; set; } = "https://www.instagram.com/JTAKcompany/";

        /// <summary>
        /// Official YouTube channel URL.
        /// </summary>
        public string YoutubeUrl { get; set; } = "https://www.youtube.com/channel/UCXEnrIm0euKKFEQOROAQPSQ";

        /// <summary>
        /// Official Telegram channel or support link (optional).
        /// </summary>
        public string TelegramUrl { get; set; } = "";

        /// <summary>
        /// Working hours description in Arabic.
        /// </summary>
        public string WorkingHoursAr { get; set; } = "يومياً 9:00 ص - 12:00 منتصف الليل";

        /// <summary>
        /// Working hours description in English.
        /// </summary>
        public string WorkingHoursEn { get; set; } = "Daily 9:00 AM - 12:00 Midnight";

        /// <summary>
        /// Office / Headquarters address in Arabic.
        /// </summary>
        public string AddressAr { get; set; } = "سوريا - حمص";

        /// <summary>
        /// Office / Headquarters address in English.
        /// </summary>
        public string AddressEn { get; set; } = "Syria - Homs";

        /// <summary>
        /// Auto-normalizes and formats phone numbers if missing or unformatted.
        /// </summary>
        public string ValidationError()
        {
            if (!System.Text.RegularExpressions.Regex.IsMatch(PhoneNumber ?? "", @"^(09[0-9]{8}|\+?[1-9][0-9]{8,14})$"))
                return "أدخل رقم اتصال صالحاً، مثل 0985615705 أو +963985615705.";
            if (!System.Text.RegularExpressions.Regex.IsMatch(WhatsAppNumber ?? "", @"^[1-9][0-9]{8,14}$"))
                return "أدخل رقم واتساب صالحاً مع رمز البلد.";
            if (string.IsNullOrWhiteSpace(SupportEmail) || SupportEmail.Length > 254 ||
                !System.Net.Mail.MailAddress.TryCreate(SupportEmail, out var email) || email.Address != SupportEmail)
                return "أدخل بريداً إلكترونياً صالحاً للدعم.";
            foreach (var url in new[] { FacebookUrl, InstagramUrl, YoutubeUrl, TelegramUrl })
                if (!string.IsNullOrEmpty(url) && (url.Length > 2048 || !Uri.TryCreate(url, UriKind.Absolute, out var uri) ||
                    (uri.Scheme != Uri.UriSchemeHttps && uri.Scheme != Uri.UriSchemeHttp) || string.IsNullOrEmpty(uri.Host) || !string.IsNullOrEmpty(uri.UserInfo)))
                    return "روابط التواصل يجب أن تبدأ بـ https:// أو http:// وتكون صالحة.";
            foreach (var text in new[] { WorkingHoursAr, WorkingHoursEn, AddressAr, AddressEn })
                if ((text?.Length ?? 0) > 1000) return "ساعات العمل والعنوان يجب ألا تتجاوز 1000 حرف.";
            return null;
        }

        public void Normalize()
        {
            if (!string.IsNullOrWhiteSpace(PhoneNumber))
            {
                PhoneNumber = System.Text.RegularExpressions.Regex.Replace(PhoneNumber.Trim(), @"[\s()\-]", "");
                var digits = System.Text.RegularExpressions.Regex.Replace(PhoneNumber, @"[^\d]", "");

                // Derived dial/display values always follow the primary number.
                PhoneInternational = digits.StartsWith("09") && digits.Length == 10
                    ? "+963" + digits.Substring(1) : "+" + digits;
                if (System.Text.RegularExpressions.Regex.IsMatch(PhoneNumber, @"^\+?[1-9][0-9]{8,14}$"))
                    PhoneNumber = PhoneInternational;
                PhoneFormatted = digits.StartsWith("09") && digits.Length == 10
                    ? $"{digits.Substring(0, 4)} {digits.Substring(4, 3)} {digits.Substring(7)}" : PhoneNumber;
            }

            if (!string.IsNullOrWhiteSpace(WhatsAppNumber))
            {
                WhatsAppNumber = System.Text.RegularExpressions.Regex.Replace(WhatsAppNumber.Trim(), @"[+\s()\-]", "");
                if (WhatsAppNumber.StartsWith("09") && WhatsAppNumber.Length == 10)
                {
                    WhatsAppNumber = "963" + WhatsAppNumber.Substring(1);
                }
            }
            else if (!string.IsNullOrWhiteSpace(PhoneInternational))
            {
                var clean = System.Text.RegularExpressions.Regex.Replace(PhoneInternational, @"[^\d]", "");
                WhatsAppNumber = clean;
            }

            if (!string.IsNullOrWhiteSpace(SupportEmail))
                SupportEmail = SupportEmail.Trim().ToLowerInvariant();

            FacebookUrl = FacebookUrl?.Trim() ?? string.Empty;
            InstagramUrl = InstagramUrl?.Trim() ?? string.Empty;
            YoutubeUrl = YoutubeUrl?.Trim() ?? string.Empty;
            TelegramUrl = TelegramUrl?.Trim() ?? string.Empty;
            WorkingHoursAr = WorkingHoursAr?.Trim() ?? string.Empty;
            WorkingHoursEn = WorkingHoursEn?.Trim() ?? string.Empty;
            AddressAr = AddressAr?.Trim() ?? string.Empty;
            AddressEn = AddressEn?.Trim() ?? string.Empty;
        }
    }
}
