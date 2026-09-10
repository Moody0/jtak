using System;
using System.Linq;
using System.Threading.Tasks;
using AutoMapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using App.Shared.Entities;
using App.Shared.Data.App;

namespace App.Shared.Services.Hubs
{
    public class NotificationHub : Microsoft.AspNetCore.SignalR.Hub
    {
        private readonly IMapper _mapper;
        private readonly IAppUnitOfWork _unitOfWork;
        private readonly INotificationService _notificationService;
        private readonly UserManager<AppUser> _userManager;

        public NotificationHub(IAppUnitOfWork unitOfWork, UserManager<AppUser> userManager, INotificationService notificationService, IMapper mapper)
        {
            _userManager = userManager;
            _notificationService = notificationService;
            _mapper = mapper;
            _unitOfWork = unitOfWork;
        }

        [Authorize]
        public async Task ReadAllNotifications()
        {
            var sender = await _userManager.GetUserAsync(Context.User);
            if (sender == null) return;
            await _notificationService.MarkAsRead(sender.Id);
        }

        public override async Task OnConnectedAsync()
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, _notificationService.DefaultNotificationGroup);
            await base.OnConnectedAsync();

            var sender = await _userManager.GetUserAsync(Context.User);
            if (sender == null) return;

            var notifications = _notificationService.Queryable()
                .Where(x => x.NotificationMessages.Any(z => z.UserId == sender.Id && z.ReadDate == null))
                .OrderByDescending(x => x.CreatedDate)
                .Take(5)
                .ToList()
                .OrderBy(x => x.CreatedDate);
            foreach (var n in notifications)
            {
                await _notificationService.SendSignalRNotification(sender.Id, n);
            }
        }


        public override async Task OnDisconnectedAsync(Exception exception)
        {
            await Groups.RemoveFromGroupAsync(Context.ConnectionId, "YOS TEK Group");
            await base.OnDisconnectedAsync(exception);
        }
    }
}