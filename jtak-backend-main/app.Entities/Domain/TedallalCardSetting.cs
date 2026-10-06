using System;

namespace App.Shared.Entities.Domain
{
    /// <summary>
    /// Configuration for the "خدمة تدلل" card on the customer home page.
    /// Fully customizable by the administrator via the dashboard.
    /// </summary>
    public class TedallalCardSetting
    {
        public const string Key = "TedallalCardSetting";

        /// <summary>
        /// Whether the card is visible on the home page.
        /// </summary>
        public bool Enabled { get; set; } = true;

        /// <summary>
        /// Section title above the card (e.g. "خدمة تدلل").
        /// </summary>
        public string SectionTitle { get; set; } = "خدمة تدلل";

        /// <summary>
        /// Main card title (e.g. "طلبات خاصة وعروض الأسعار").
        /// </summary>
        public string CardTitle { get; set; } = "طلبات خاصة وعروض الأسعار";

        /// <summary>
        /// Subtitle / hint text inside the card.
        /// </summary>
        public string Subtitle { get; set; } = "اطلب أي شيء غير متوفر في التطبيق مع عروض أسعار فورية";

        /// <summary>
        /// Optional custom icon or logo image URL. If empty, falls back to default app icon.
        /// </summary>
        public string LogoUrl { get; set; } = "";

        public void Normalize()
        {
            SectionTitle = string.IsNullOrWhiteSpace(SectionTitle) ? "خدمة تدلل" : SectionTitle.Trim();
            CardTitle = string.IsNullOrWhiteSpace(CardTitle) ? "طلبات خاصة وعروض الأسعار" : CardTitle.Trim();
            Subtitle = string.IsNullOrWhiteSpace(Subtitle) ? "اطلب أي شيء غير متوفر في التطبيق مع عروض أسعار فورية" : Subtitle.Trim();
            LogoUrl = (LogoUrl ?? "").Trim();
        }
    }
}
