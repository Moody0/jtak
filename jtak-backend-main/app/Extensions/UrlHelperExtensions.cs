using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Html;
using System;
using System.Globalization;

namespace App.Extensions
{
    public static class UrlHelperExtensions
    {
        public static string EmailConfirmationLink(this IUrlHelper _helper, Guid userId, string code) =>
            _helper.Action("ConfirmEmail", "Account", new { userId, code, area = "", culture = CultureInfo.CurrentCulture.TwoLetterISOLanguageName }, "https");

        public static string EmailChangeLink(this IUrlHelper _helper, Guid userId, string newemail, string code) =>
            _helper.Action("ConfirmChangeEmail", "Account", new { userId, newemail, code, area = "", culture = CultureInfo.CurrentCulture.TwoLetterISOLanguageName }, "https");

        public static string ImgHref(this IUrlHelper _helper, string _dbField, int w = 150, int h = 150, bool crop = false) =>
            _helper.Action("PreviewImage", "Services", new { area = "", id = _dbField, w, h, crop });

        public static string DownloadHref(this IUrlHelper _helper, string _dbField) =>
            _helper.Action("Download", "Services", new { area = "", id = _dbField });

        public static HtmlString DownloadLink(this IUrlHelper _helper, string buttonTitle, string id) =>
            string.IsNullOrEmpty(id) ? HtmlString.Empty : new HtmlString($"<a href='{_helper.DownloadHref(id)}' target='_blank' class='btn btn-sm btn-info'> <i class='fa fa-download'></i> {buttonTitle}</a>");

        public static HtmlString ImgTag(this IUrlHelper _helper, string _dbField, int w = 150, int h = 150, bool crop = false) =>
            new HtmlString($"<img src='{_helper.ImgHref(_dbField, w, h, crop)}' />");
    }
}
