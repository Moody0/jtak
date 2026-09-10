namespace App.Models
{
    public class AppPreferences
    {
        public int RejectedOrderReminderTimeout { get; set; } = 5;
        public int AcceptedOrderReminderTimeout { get; set; } = 5;
    }
}
