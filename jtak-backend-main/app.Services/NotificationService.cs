using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using FirebaseAdmin;
using Google.Apis.Auth.OAuth2;
using App.Shared.Services.Extentions;
using Microsoft.Extensions.Logging;
using App.Shared.Services.Hubs;
using System.Reflection;
using App.Shared.Services.Options;
using System.Net.Http;
using App.Shared.Entities;
using App.Shared.Data.App;
using App.Shared.Data.MultiContext;
using System.Data;
using System.Threading;
using MySqlConnector;
using App.Shared.Services.BackroundTasks;
using Solf.Base;
using App.Shared.Services.Helpers;

namespace App.Shared.Services
{
    public interface INotificationService : ISolService<Notification, NotificationDto>
    {
        string DefaultNotificationGroup { get; }

        Task<Notification[]> GetNotifications(Guid? uid, DateTime? fromDate = null, DateTime? updateBefore = null, DateTime? updateAfter = null);

        Task MarkAsRead(Guid? uid, long? id = null);
        Task MarkAsRecived(Guid? uid, long? id = null);
        Task<int> CountUnreadNotifications(Guid uid);

        Task QueuePushNotification(Notification n, Guid[] recivers, bool saveNotification = true, bool suppressedNotification = false);
        Task SendPushNotification(Notification n, Guid[] recivers, bool saveNotification = true, bool suppressedNotification = false);

        Task SendSignalRNotification(Guid uid, Notification n);
        Task SendChatMessageNotificationAsync(Guid uid, object c);

        Task<string> SendSmsNotification(string phoneNumber, string msg);


        Guid GetUserTopic(Guid uid);

    }
    public class NotificationService : SolService<Notification, NotificationDto>, INotificationService
    {
        private SolAppOptions AppOptions { get; }
        private NotificationOptions Options { get; }
        private readonly UserManager<AppUser> _userManager;
        private readonly IHubContext<NotificationHub> _nHubContext;
        private readonly INotificationMessageRepo _nmRepo;
        private readonly IAppUnitOfWork _unitOfWork;
        private readonly ILogger _logger;
        private readonly IBackgroundTaskQueue _taskQueue;

        public NotificationService(ITrackableRepository<Notification, AppDbContext> repository,
            INotificationMessageRepo nmRepo,
            IOptions<SolAppOptions> appOptions,
            IOptions<NotificationOptions> options,
            IHubContext<NotificationHub> nHubContext,
            UserManager<AppUser> userManager,
            IAppUnitOfWork unitOfWork,
            IBackgroundTaskQueue taskQueue,
            ILogger<NotificationService> logger) : base(repository)
        {
            _nHubContext = nHubContext;
            _userManager = userManager;
            _nmRepo = nmRepo;
            _unitOfWork = unitOfWork;
            _logger = logger;
            Options = options.Value;
            AppOptions = appOptions.Value;


            _taskQueue = taskQueue;
        }

        public string DefaultNotificationGroup { get; } = "all";


        public async Task<Notification[]> GetNotifications(Guid? uid, DateTime? fromDate = null, DateTime? updateBefore = null, DateTime? updateAfter = null)
        {
            var myTopics = new List<string> { DefaultNotificationGroup };

            var entity = NotificationType.GlobalNotification;
            Notification[] notifications = null;
            if (uid == null)
            {
                notifications = await Repository
                                    .Queryable()
                                    .Where(x => x.NotificationType == entity &&
                                                myTopics.Contains(x.Topic) &&
                                                (fromDate == null || x.CreatedDate < fromDate))
                                    .OrderByDescending(x => x.CreatedDate)
                                    .Take(20)
                                    .ToArrayAsync();

                foreach (var notification in notifications.Where(x => !updateBefore.HasValue || !updateAfter.HasValue || x.CreatedDate > updateAfter || x.CreatedDate < updateBefore))
                {
                    notification.NotLoggedInReadCount++;
                }
                await _unitOfWork.SaveChangesAsync();
            }
            else
            {
                // WORKING DON'T TOUCH IT !!
                notifications = await Repository
                                    .Queryable()
                                    .Where(x => x.NotificationMessages.Any(m => m.UserId == uid) && (fromDate == null || x.CreatedDate < fromDate))
                                    .OrderByDescending(x => x.CreatedDate)
                                    .Take(20)
                                    .ToArrayAsync();

                var nids = notifications.Select(x => x.Id).ToArray();
                var toBeMaredAsRead = _nmRepo
                                    .Queryable()
                                        .Where(n => nids.Contains(n.NotificationId) && n.UserId == uid && n.ReadDate == null)
                                        .ToArray();

                var now = DateTime.UtcNow;
                if (toBeMaredAsRead.Any())
                {
                    foreach (var nm in toBeMaredAsRead)
                    {
                        if (nm.ReadDate == null)
                        {
                            nm.RecivedDate = now;
                            nm.ReadDate = now;
                            _nmRepo.Update(nm);
                        }
                    }
                    await _unitOfWork.SaveChangesAsync();
                }
            }
            return notifications;
        }

        public async Task MarkAsRead(Guid? uid, long? id)
        {
            if (uid == null)
            {
                var notificationMessages = await _nmRepo.Queryable().Where(x => x.UserId == uid && (id == null || x.NotificationId == id)).ToArrayAsync();
                foreach (var notificationMessage in notificationMessages)
                {
                    notificationMessage.RecivedDate ??= DateTime.UtcNow;
                    notificationMessage.ReadDate = DateTime.UtcNow;
                }
            }
            else
            {
                var notification = await Repository.Queryable().FirstOrDefaultAsync(x => x.Id == id);
                notification.NotLoggedInReadCount++;
            }
            await _nHubContext.Clients.User(uid.ToString()).SendAsync("NotificationCountUpdated", 0);
            await _unitOfWork.SaveChangesAsync();
        }

        public async Task MarkAsRecived(Guid? uid, long? id)
        {
            if (uid == null)
            {
                var notificationMessages = await _nmRepo.Queryable().Where(x => x.UserId == uid && (id == null || x.NotificationId == id)).ToArrayAsync();
                foreach (var notificationMessage in notificationMessages) notificationMessage.RecivedDate = DateTime.UtcNow;
            }
            else
            {
                var notification = await Repository.Queryable().FirstOrDefaultAsync(x => x.Id == id);
                notification.NotLoggedInRecivedCount++;
            }
            await _unitOfWork.SaveChangesAsync();
        }

        public async Task<int> CountUnreadNotifications(Guid uid) =>
            await _nmRepo.Queryable().CountAsync(x => x.UserId == uid && x.ReadDate == null);

        public async Task QueuePushNotification(Notification n, Guid[] recivers, bool saveNotification = true, bool suppressedNotification = false)
        {
            await _taskQueue.QueueBackgroundWorkItemAsync(async (CancellationToken token) =>
            {
                _logger.LogError("Executing QueueBackgroundNotificationAsync");
                await SendPushNotification(n, recivers, saveNotification, suppressedNotification);
            });
        }

        public async Task SendPushNotification(Notification n, Guid[] recivers, bool saveNotification = true, bool suppressedNotification = false)
        {
            try
            {
                var currentDir = Path.GetDirectoryName(Assembly.GetEntryAssembly().Location); ;
                string path = currentDir + "/jtak-339412-firebase-adminsdk-fyug6-170c77def3.json";
                if (FirebaseApp.DefaultInstance == null)
                    FirebaseApp.Create(new AppOptions() { Credential = GoogleCredential.FromFile(path) });

                if (saveNotification)
                {
                    Repository.Insert(n);
                    await _unitOfWork.SaveChangesAsync();
                    // Not working !
                    _nmRepo.Insert(recivers.Select(x => new NotificationMessage { NotificationId = n.Id, UserId = x }));
                    await _unitOfWork.SaveChangesAsync();
                    //await _nmRepo.BulkInsertAsync(n.Id, recivers);
                }
            }
            catch (Exception e)
            {
                _logger.LogError(e.ToString());
            }
            /****************************************************************************************************/

            var topics = n.Topic?.Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries);
            if (topics?.Any() != true)
            {
                // if no actual topics specified, generate user topic guids based on user id
                topics = recivers.Select(x => GetUserTopic(x).ToString()).ToArray();
            }
            foreach (var topic in topics)
            {
                try
                {
                    foreach (var lang in AppOptions.SupportedLanguages)
                    {
                        var dataPayload = n.GetPayload(lang);
                        var imgUrl = string.IsNullOrEmpty(n.Image) ? null : AppDomainHelper.ApiUrl + n.Image;
                        var notif = suppressedNotification ? null : new FirebaseAdmin.Messaging.Notification { Title = n.GetTitle(lang), Body = n.GetText(lang), ImageUrl = imgUrl };
                        // Image config for iOS APNS
                        var android = new FirebaseAdmin.Messaging.AndroidConfig { Notification = new FirebaseAdmin.Messaging.AndroidNotification { Sound = "default" } };
                        var apns = new FirebaseAdmin.Messaging.ApnsConfig { Aps = new FirebaseAdmin.Messaging.Aps { MutableContent = true, Sound = "default" }, FcmOptions = new FirebaseAdmin.Messaging.ApnsFcmOptions { ImageUrl = imgUrl } };

                        var msg = new FirebaseAdmin.Messaging.Message { Notification = notif, Data = dataPayload, Topic = $"{topic}_{lang}", Apns = apns, Android = android };
                        var result = await FirebaseAdmin.Messaging.FirebaseMessaging.DefaultInstance.SendAsync(msg);
                    }

                    //var dataPayload2 = n.GetPayload("ar");
                    //
                    //var notif2 = suppressedNotification ? null : new FirebaseAdmin.Messaging.Notification { Title = n.GetTitle("ar"), Body = n.GetText("ar"), ImageUrl = imgUrl };
                    //// Image config for iOS APNS
                    //var apns2 = new FirebaseAdmin.Messaging.ApnsConfig { Aps = new FirebaseAdmin.Messaging.Aps { MutableContent = true }, FcmOptions = new FirebaseAdmin.Messaging.ApnsFcmOptions { ImageUrl = n.Image } };
                    //
                    //var msg2 = new FirebaseAdmin.Messaging.Message { Notification = notif2, Data = dataPayload2, Topic = topic, Apns = apns2 };
                    //var result2 = await FirebaseAdmin.Messaging.FirebaseMessaging.DefaultInstance.SendAsync(msg2);
                }
                catch (Exception e)
                {
                    _logger.LogError(e.ToString());
                }
            }
        }

        public async Task SendSignalRNotification(Guid uid, Notification n)
        {
            await _nHubContext.Clients.User(uid.ToString()).SendAsync("ReceiveNotification", n);
            var ncount = await CountUnreadNotifications(uid);
            await _nHubContext.Clients.User(uid.ToString()).SendAsync("NotificationCountUpdated", ncount.ToString());
        }
        public async Task SendChatMessageNotificationAsync(Guid uid, object c) =>
            await _nHubContext.Clients.User(uid.ToString()).SendAsync("ReceiveChatMessage", c);


        public async Task<string> SendSmsNotification(string phoneNumber, string msg)
        {
            //try
            //{
            //    // Find your Account Sid and Token at twilio.com/console
            //    TwilioClient.Init(Options.TwilioAccountSid, Options.TwilioAuthToken);
            //
            //    var message = await MessageResource.CreateAsync(
            //        body: msg,
            //        from: new Twilio.Types.PhoneNumber(Options.TwilioMobile),
            //        to: new Twilio.Types.PhoneNumber(phoneNumber)
            //    );
            //
            //    return message.Sid;
            //}
            //catch (Exception e)
            //{
            //    _logger.LogError(e.ToString());
            //}
            //return null;

            phoneNumber = phoneNumber?.Trim().Replace(" ", "").Replace("+", "");
            using var client = new HttpClient();

            var response = await client.PostAsync("https://www.turkeysms.com.tr/api/v3/gonder/add-content",
                new StringContent("{\"api_key\":\"29a63653e5b833f8a4fda435616630e1\",\"title\":\"8507013986\",\"text\":\"" + msg + "\",\"sentto\":\"" + phoneNumber + "\",\"report\":1}",
                  Encoding.UTF8,
                  "application/json"
                  ));

            //_logger.LogError($@"SMS log: Sending message: {msg}
            //                to: {phoneNumber.Replace("+", "")}
            //                ({response.StatusCode}) {await response.Content.ReadAsStringAsync()}");
            return null;
        }
        public Guid GetUserTopic(Guid uid) =>
            GuidExt.FromString(uid.ToString() + Options.UserTopicSalt);

    }
    public interface INotificationMessageRepo : ITrackableRepository<NotificationMessage, AppDbContext>
    {
        Task BulkInsertAsync(int notificationId, Guid[] recivers);
    }
    public class NotificationMessageRepo : TrackableRepository<NotificationMessage, AppDbContext>, INotificationMessageRepo
    {
        public NotificationMessageRepo(AppDbContext context) : base(context)
        {
        }

        public async Task BulkInsertAsync(int notificationId, Guid[] recivers)
        {
            //var sw = new System.Diagnostics.Stopwatch();
            var items = recivers.Select(x => (UserId: x, NotificationId: notificationId)).ToArray();
            var dt = new DataTable();
            dt.Columns.Add("ViewDate");
            dt.Columns.Add("UserId");
            dt.Columns.Add("NotificationId");

            foreach (var item in items)
                dt.Rows.Add(DBNull.Value, item.UserId, item.NotificationId);
            await Context.Database.OpenConnectionAsync();
            var cs = Context.Database.GetConnectionString();
            var connection = Context.Database.GetDbConnection() as MySqlConnection;
            using (var transaction = connection.BeginTransaction())
            {
                var sqlBulk = new MySqlBulkCopy(connection, transaction)
                {
                    DestinationTableName = "NotificationMessage",
                };
                //MySqlBulkLoader.Local = true;
                await sqlBulk.WriteToServerAsync(dt);

                transaction.Commit();
            }
            connection.Close();
            //sw.Start();
            //_logger.LogError($"{DateTime.UtcNow:O} Insterted {nms.Count()} NotificationMessage in {sw.ElapsedMilliseconds}ms");
        }
    }
}