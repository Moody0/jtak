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
        public void Normalize()
        {
            if (!string.IsNullOrWhiteSpace(PhoneNumber))
            {
                PhoneNumber = PhoneNumber.Trim();
                var digits = System.Text.RegularExpressions.Regex.Replace(PhoneNumber, @"[^\d]", "");

                if (string.IsNullOrWhiteSpace(PhoneInternational))
                {
                    if (digits.StartsWith("09") && digits.Length == 10)
                        PhoneInternational = "+963" + digits.Substring(1);
                    else if (digits.StartsWith("963"))
                        PhoneInternational = "+" + digits;
                    else
                        PhoneInternational = PhoneNumber.StartsWith("+") ? PhoneNumber : "+" + PhoneNumber;
                }

                if (string.IsNullOrWhiteSpace(PhoneFormatted))
                {
                    if (digits.Length == 10 && digits.StartsWith("09"))
                        PhoneFormatted = $"{digits.Substring(0, 4)} {digits.Substring(4, 3)} {digits.Substring(7)}";
                    else
                        PhoneFormatted = PhoneNumber;
                }
            }

            if (!string.IsNullOrWhiteSpace(WhatsAppNumber))
            {
                WhatsAppNumber = System.Text.RegularExpressions.Regex.Replace(WhatsAppNumber, @"[^\d]", "");
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
