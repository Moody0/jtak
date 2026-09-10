using Solf.Base;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;

namespace App.Shared.Services.Extentions
{
    public static class MultilingualEntityExtentions
    {
        public static T CurrentOrDefault<T>(this ICollection<T> q) where T : IEntityTranslation
        {
            return q.Any(x => x.Language == CultureInfo.CurrentCulture.TwoLetterISOLanguageName) ? q.FirstOrDefault(x => x.Language == CultureInfo.CurrentCulture.TwoLetterISOLanguageName) : q.FirstOrDefault();
        }
        public static T Current<T>(this ICollection<T> q) where T : IEntityTranslation
        {
            return q.FirstOrDefault(x => x.Language == CultureInfo.CurrentCulture.TwoLetterISOLanguageName);
        }
    }
}
