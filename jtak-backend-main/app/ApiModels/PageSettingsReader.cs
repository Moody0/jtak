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
            if (HasBody(page)) return EnsureTitle(page, key);

            // The previous MVC editor used a PageVm-compatible model and a PageVm suffix.
            page = await settings.GetValue<PageVm>($"{key}PageVm", language);
            if (HasBody(page)) return EnsureTitle(page, key);

            // Early seeds stored the HTML as a JSON string instead of a page object.
            var body = await settings.GetValue<string>(key, language);
            if (!string.IsNullOrWhiteSpace(body))
                return new PageVm { Title = key, Body = body };

            return new PageVm { Title = key, Body = string.Empty };
        }

        private static bool HasBody(PageVm page) => page != null && !string.IsNullOrWhiteSpace(page.Body);

        private static PageVm EnsureTitle(PageVm page, string key)
        {
            page.Title = string.IsNullOrWhiteSpace(page.Title) ? key : page.Title;
            return page;
        }
    }
}
