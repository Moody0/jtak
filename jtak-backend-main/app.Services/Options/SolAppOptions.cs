using Microsoft.AspNetCore.Localization;
using Solf.Enums;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;

namespace App.Shared.Services.Options
{
    public class SolAppOptions
    {
        public string DefaultLanguage { get; set; }
        public string[] SupportedLanguages { get; set; }
        public List<CultureInfo> SupportedCultures =>
            SupportedLanguages.Select(x => new CultureInfo(x.ToString().ToLower()) { DateTimeFormat = { Calendar = new GregorianCalendar() } }).ToList();
        public RequestCulture DefaultRequestCulture => new RequestCulture(DefaultLanguage);

        /// <summary>
        /// List languages as dictionary to display in DropDownList 
        /// </summary>
        public LanguageCode[] ListLanguageCodes(string otherThan = "") =>
            Enum.GetValues<LanguageCode>().Where(x => SupportedLanguages.Contains(x.ToString().ToLower()) && x.ToString().ToLower() != otherThan.ToLower()).ToArray();
    }
}
