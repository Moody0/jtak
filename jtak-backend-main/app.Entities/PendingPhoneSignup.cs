using System;
using System.ComponentModel.DataAnnotations;

namespace App.Shared.Entities
{
    /// <summary>
    /// Short-lived OTP challenge for a phone number that does not yet have a
    /// complete customer profile. No AppUser is created until the customer
    /// supplies a name and verifies this challenge.
    /// </summary>
    public sealed class PendingPhoneSignup
    {
        [Key]
        [MaxLength(16)]
        public string PhoneNumber { get; set; }

        [Required]
        [MaxLength(6)]
        public string Code { get; set; }

        public DateTime ExpiresAt { get; set; }

        public int FailedAttempts { get; set; }
    }
}
