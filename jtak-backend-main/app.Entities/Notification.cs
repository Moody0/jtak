using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Threading;
using App.Shared.Entities.Resources;
using Solf.Base;

namespace App.Shared.Entities
{
    public class Notification : AuditableEntity
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        [Display(Name = "Id", ResourceType = typeof(_Entities))]
        public int Id { get; set; }

        #region Title
        [Display(Name = "TitleAr", ResourceType = typeof(_Entities))]
        public string TitleAr { get; set; }

        [Display(Name = "TitleEn", ResourceType = typeof(_Entities))]
        public string TitleEn { get; set; }

        [Display(Name = "TitleTr", ResourceType = typeof(_Entities))]
        public string TitleTr { get; set; }

        [Display(Name = "Title", ResourceType = typeof(_Entities))]
        public string Title => GetTitle(Thread.CurrentThread.CurrentCulture.TwoLetterISOLanguageName);
        public string GetTitle(string lang) => lang == "ar" ? TitleAr : lang == "tr" ? TitleTr : TitleEn;
        #endregion

        #region Text
        [Display(Name = "TextAr", ResourceType = typeof(_Notification))]
        public string TextAr { get; set; }

        [Display(Name = "TextEn", ResourceType = typeof(_Notification))]
        public string TextEn { get; set; }

        [Display(Name = "TextTr", ResourceType = typeof(_Notification))]
        public string TextTr { get; set; }

        [Display(Name = "Text", ResourceType = typeof(_Notification))]
        public string Text => GetText(Thread.CurrentThread.CurrentCulture.TwoLetterISOLanguageName);
        public string GetText(string lang) => lang == "ar" ? TextAr : lang == "tr" ? TextTr : TextEn;
        #endregion

        [Display(Name = "Image", ResourceType = typeof(_Notification))]
        public string Image { get; set; }

        [Display(Name = "Url", ResourceType = typeof(_Notification))]
        public string Url { get; set; }

        [Display(Name = "Topic", ResourceType = typeof(_Notification))]
        public string Topic { get; set; }

        public NotificationType NotificationType { get; set; }

        public string EntityData { get; set; }

        public int NotLoggedInRecivedCount { get; set; }
        public int NotLoggedInReadCount { get; set; }

        [InverseProperty("Notification")]
        public virtual ICollection<NotificationMessage> NotificationMessages { get; set; }


        public Dictionary<string, string> GetPayload(string lang) => new Dictionary<string, string>()
        {
            ["Id"] = Id.ToString("D"),
            ["Title"] = lang == "ar" ? TitleAr : lang == "tr" ? TitleTr : TitleEn,
            ["Text"] = lang == "ar" ? TextAr : lang == "tr" ? TextTr : TextEn,
            ["Url"] = Url,
            ["ImageUrl"] = Image,
            ["Topic"] = Topic,
            ["Entity"] = NotificationType.ToString(),
            ["EntityData"] = EntityData,
            ["CreatedDate"] = CreatedDate.ToString("O")
        };
    }
    public class NotificationDto
    {
        public int Id { get; set; }

        #region Title
        public string TitleAr { get; set; }

        public string TitleEn { get; set; }

        public string TitleTr { get; set; }

        public string Title => GetTitle(Thread.CurrentThread.CurrentCulture.TwoLetterISOLanguageName);
        public string GetTitle(string lang) => lang == "ar" ? TitleAr : lang == "tr" ? TitleTr : TitleEn;
        #endregion

        #region Text
        public string TextAr { get; set; }

        public string TextEn { get; set; }

        public string TextTr { get; set; }

        public string Text => GetText(Thread.CurrentThread.CurrentCulture.TwoLetterISOLanguageName);
        public string GetText(string lang) => lang == "ar" ? TextAr : lang == "tr" ? TextTr : TextEn;
        #endregion

        public NotificationType NotificationType { get; set; }

        public string Image { get; set; }

        public string Url { get; set; }

    }

    //[JsonConverter(typeof(JsonStringEnumConverter))]
    public enum NotificationType
    {
        GlobalNotification = 0,
        Order = 1,
        Payment = 2
    }
}
