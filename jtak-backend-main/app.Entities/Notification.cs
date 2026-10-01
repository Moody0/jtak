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

        // The business event is transient; its per-recipient hash is persisted.
        [NotMapped]
        public string EventKey { get; set; }
        public string DispatchKey { get; set; }
        public string AudienceApp { get; set; }
        public System.DateTime? PushSentAtUtc { get; set; }
        public System.Guid? PushLockId { get; set; }
        public System.DateTime? PushLockedUntilUtc { get; set; }
        public System.DateTime? PushNextAttemptAtUtc { get; set; }
        public int PushAttemptCount { get; set; }

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
            // Firebase data messages do not accept null values. Optional
            // notification fields must be sent as empty strings instead.
            ["Id"] = Id.ToString("D"),
            ["EventKey"] = DispatchKey ?? Id.ToString("D"),
            ["AudienceApp"] = AudienceApp ?? string.Empty,
            ["Title"] = (lang == "ar" ? TitleAr : lang == "tr" ? TitleTr : TitleEn) ?? string.Empty,
            ["Text"] = (lang == "ar" ? TextAr : lang == "tr" ? TextTr : TextEn) ?? string.Empty,
            ["Url"] = Url ?? string.Empty,
            ["ImageUrl"] = Image ?? string.Empty,
            ["Topic"] = Topic ?? string.Empty,
            ["Entity"] = NotificationType.ToString(),
            ["EntityData"] = EntityData ?? string.Empty,
            ["CreatedDate"] = CreatedDate.ToString("O")
        };
    }
    public class NotificationDto
    {
        public int Id { get; set; }
        public System.DateTime CreatedDate { get; set; }
        public string Topic { get; set; }

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
