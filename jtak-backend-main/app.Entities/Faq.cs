using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Threading;
using App.Shared.Entities.Resources;
using Solf.Base;

namespace App.Shared.Entities.Domain
{
    public class Faq : AuditableEntity
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        [Display(Name = "Id", ResourceType = typeof(_Entities))]
        public int Id { get; set; }

        #region Question
        [Display(Name = "QuestionAr", ResourceType = typeof(_Faq))]
        public string QuestionAr { get; set; }

        [Display(Name = "QuestionEn", ResourceType = typeof(_Faq))]
        public string QuestionEn { get; set; }

        [Display(Name = "QuestionTr", ResourceType = typeof(_Faq))]
        public string QuestionTr { get; set; }
        [Display(Name = "Question", ResourceType = typeof(_Faq))]
        public string Question => Thread.CurrentThread.CurrentCulture.TwoLetterISOLanguageName.ToLower() switch
        {
            "ar" => QuestionAr,
            "en" => QuestionEn,
            "tr" => QuestionTr,
            _ => QuestionAr,
        };
        #endregion

        #region Answer
        [UIHint("Multiline")]
        [Display(Name = "AnswerAr", ResourceType = typeof(_Faq))]
        public string AnswerAr { get; set; }

        [UIHint("Multiline")]
        [Display(Name = "AnswerEn", ResourceType = typeof(_Faq))]
        public string AnswerEn { get; set; }

        [UIHint("Multiline")]
        [Display(Name = "AnswerTr", ResourceType = typeof(_Faq))]
        public string AnswerTr { get; set; }

        [Display(Name = "Answer", ResourceType = typeof(_Faq))]
        public string Answer => Thread.CurrentThread.CurrentCulture.TwoLetterISOLanguageName.ToLower() switch
        {
            "ar" => AnswerAr,
            "en" => AnswerEn,
            "tr" => AnswerTr,
            _ => AnswerAr,
        };
        #endregion
    }
    public class FaqLiteDto
    {
        public int Id { get; set; }

        public string Question { get; set; }
        public string Answer { get; set; }
    }
}
