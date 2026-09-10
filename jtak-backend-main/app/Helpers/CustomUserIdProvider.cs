using Microsoft.AspNetCore.SignalR;
using App.Extensions;

namespace App.Helpers
{
    public class CustomUserIdProvider: IUserIdProvider
    {
        public virtual string GetUserId(HubConnectionContext connection) => connection.User.GetUserId().ToString();
    }
}
