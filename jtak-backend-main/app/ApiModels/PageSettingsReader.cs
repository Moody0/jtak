using App.Shared.Services;
using System.Threading.Tasks;

namespace App.ApiModels
{
    /// <summary>Reads page settings written by both the API and the legacy MVC editor.</summary>
    public static class PageSettingsReader
    {
        public static async Task<PageVm> GetPage(IGenericSettingService settings, string key, string language)
        {
            var page = await settings.GetValue<PageVm>(key, language);
            if (HasBody(page)) return EnsureTitle(page, key, language);

            // The previous MVC editor used a PageVm-compatible model and a PageVm suffix.
            page = await settings.GetValue<PageVm>($"{key}PageVm", language);
            if (HasBody(page)) return EnsureTitle(page, key, language);

            // Early seeds stored the HTML as a JSON string instead of a page object.
            var body = await settings.GetValue<string>(key, language);
            if (!string.IsNullOrWhiteSpace(body))
                return new PageVm { Title = FriendlyTitle(key, language), Body = body };

            return new PageVm { Title = FriendlyTitle(key, language), Body = string.Empty };
        }

        public static async Task<PageVm> GetTermsPage(IGenericSettingService settings, string key, string language)
        {
            var page = await GetPage(settings, key, language);
            // Retain the legacy public fallback until an explicit app policy is saved.
            return string.IsNullOrWhiteSpace(page.Body) && key != "TermsAndConditions"
                ? await GetPage(settings, "TermsAndConditions", language) : page;
        }

        private static bool HasBody(PageVm page) => page != null && !string.IsNullOrWhiteSpace(page.Body);

        private static PageVm EnsureTitle(PageVm page, string key, string language)
        {
            if (string.IsNullOrWhiteSpace(page.Title) || page.Title == key || page.Title == "TermsAndConditions")
                page.Title = FriendlyTitle(key, language);
            return page;
        }

        private static string FriendlyTitle(string key, string language)
        {
            var ar = language == "ar";
            var tr = language == "tr";
            if (key.StartsWith("TermsAndConditions")) return ar ? "الشروط والأحكام" : tr ? "Şartlar ve Koşullar" : "Terms and conditions";
            return key switch {
                "PrivacyPolicy" => ar ? "سياسة الخصوصية" : tr ? "Gizlilik Politikası" : "Privacy policy",
                "PaymentPolicy" => ar ? "سياسة الدفع" : tr ? "Ödeme Politikası" : "Payment policy",
                "About" => ar ? "عن جيتك" : tr ? "Jtak hakkında" : "About Jtak",
                _ => key
            };
        }
    }
}
