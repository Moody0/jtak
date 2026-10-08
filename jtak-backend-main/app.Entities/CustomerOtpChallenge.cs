using System;
using System.ComponentModel.DataAnnotations;

namespace App.Shared.Entities
{
    public sealed class CustomerOtpChallenge
    {
        [Key, MaxLength(16)] public string PhoneNumber { get; set; }
        public Guid ChallengeId { get; set; }
        public Guid? UserId { get; set; }
        [Required, MaxLength(64)] public string CodeHash { get; set; }
        [MaxLength(64)] public string MessageId { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime ExpiresAt { get; set; }
        public int FailedAttempts { get; set; }
        public DateTime? VerifiedAt { get; set; }
        public DateTime? ConsumedAt { get; set; }
        public bool IsReview { get; set; }
        public bool RequiresProfileCompletion { get; set; }
    }
}
