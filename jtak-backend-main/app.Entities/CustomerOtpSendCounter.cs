using System;
using System.ComponentModel.DataAnnotations;

namespace App.Shared.Entities
{
    public sealed class CustomerOtpSendCounter
    {
        [MaxLength(128)] public string Bucket { get; set; }
        public DateTime WindowStart { get; set; }
        public int SendCount { get; set; }
    }
}
