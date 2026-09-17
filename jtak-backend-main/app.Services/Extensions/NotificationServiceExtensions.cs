using App.Shared.Services.Helpers;
using App.Shared.Entities;
using Modules.Orders.Entities;
using System;
using System.Linq;
using System.Threading.Tasks;

namespace App.Shared.Services.Extentions
{
    public static class NotificationServiceExtensions
    {
        public static async Task SendMerchantNewOrderRecived(this INotificationService service,
                                                                  Guid[] ids,
                                                                  int orderId,
                                                                  OrderDetail[] items)
        {
            var desc = string.Join(Environment.NewLine, items.Select(i => $"{i.ProductTitle} ({i.ProductUnit}) ×{i.Quantity}"));
            var n = new Notification
            {
                TitleAr = $"طلب جديد #{orderId}",
                TitleEn = $"New order #{orderId}",
                TitleTr = $"Yeni taleb #{orderId}",
                TextAr = desc,
                TextEn = desc,
                TextTr = desc,
                //Topic = $"Order_{orderId}",
                Url = $"{AppDomainHelper.DashboardUrl}/Orders/NewMerchantOrder/{orderId}",
                NotificationType = NotificationType.Order
            };
            await service.SendPushNotification(n, ids);
        }
        public static async Task SendDeliveryNewOrderRecived(this INotificationService service,
                                                                  Guid[] ids,
                                                                  int orderId,
                                                                  OrderDetail[] items)
        {
            var desc = string.Join(Environment.NewLine, items.Select(i => $"{i.ProductTitle} ({i.ProductUnit}) ×{i.Quantity}"));
            var n = new Notification
            {
                TitleAr = $"طلب جديد #{orderId}",
                TitleEn = $"New order #{orderId}",
                TitleTr = $"Yeni taleb #{orderId}",
                TextAr = desc,
                TextEn = desc,
                TextTr = desc,
                //Topic = $"Order_{orderId}",
                Url = $"{AppDomainHelper.DashboardUrl}/Orders/NewDeliveryOrder/{orderId}",
                NotificationType = NotificationType.Order
            };
            await service.SendPushNotification(n, ids);
        }
        public static async Task SendDeliveryOrderReadyForPickup(this INotificationService service,
                                                                 Guid[] ids,
                                                                 int orderId,
                                                                 string merchantTitle)
        {
            var titleAr = $"الطلب #{orderId} جاهز للاستلام!";
            var titleEn = $"Order #{orderId} is ready for pickup!";
            var titleTr = $"Sipariş #{orderId} teslime hazır!";
            var textAr = $"قام {merchantTitle ?? "المتجر"} بتجهيز الطلب بالكامل وهو جاهز للتسليم الآن.";
            var textEn = $"{merchantTitle ?? "The merchant"} has prepared the order and it is ready for pickup now.";
            var textTr = $"{merchantTitle ?? "Mağaza"} siparişi hazırladı ve teslime hazır.";
            var n = new Notification
            {
                TitleAr = titleAr,
                TitleEn = titleEn,
                TitleTr = titleTr,
                TextAr = textAr,
                TextEn = textEn,
                TextTr = textTr,
                Url = $"{AppDomainHelper.DashboardUrl}/Orders/ReadyForPickup/{orderId}",
                NotificationType = NotificationType.Order
            };
            await service.SendPushNotification(n, ids);
        }
        public static async Task SendCustomerOrderReadyForPickup(this INotificationService service,
                                                                 Guid[] ids,
                                                                 int orderId,
                                                                 string merchantTitle)
        {
            var titleAr = $"طلبك جاهز #{orderId}";
            var titleEn = $"Your order is ready #{orderId}";
            var titleTr = $"Siparişiniz hazır #{orderId}";
            var textAr = $"تم تجهيز طلبك في {merchantTitle ?? "المتجر"} وبانتظار استلام المندوب.";
            var textEn = $"Your order at {merchantTitle ?? "the store"} is ready and waiting for courier pickup.";
            var textTr = $"{merchantTitle ?? "Mağaza"} siparişinizi hazırladı, kurye teslim almayı bekliyor.";
            var n = new Notification
            {
                TitleAr = titleAr,
                TitleEn = titleEn,
                TitleTr = titleTr,
                TextAr = textAr,
                TextEn = textEn,
                TextTr = textTr,
                Url = $"{AppDomainHelper.DashboardUrl}/Orders/CustomerReady/{orderId}",
                NotificationType = NotificationType.Order
            };
            await service.SendPushNotification(n, ids);
        }
        public static async Task SendOrderCanceled(this INotificationService service,
                                                        Guid[] ids,
                                                        int orderId,
                                                        OrderDetail[] items)
        {
            var desc = string.Join(Environment.NewLine, items.Select(i => $"{i.ProductTitle} ({i.ProductUnit}) ×{i.Quantity}"));
            var n = new Notification
            {
                TitleAr = $"تم إلغاء الطلب #{orderId}",
                TitleEn = $"Order cancelled #{orderId}",
                TitleTr = $"Siparişiniz iptal edildi #{orderId}",
                TextAr = desc,
                TextEn = desc,
                TextTr = desc,
                //Topic = $"Order_{orderId}",
                Url = $"{AppDomainHelper.DashboardUrl}/Orders/Cancel/{orderId}",
                NotificationType = NotificationType.Order
            };
            await service.SendPushNotification(n, ids);
        }
        public static async Task SendCustomerOrderItemsNotFound(this INotificationService service,
                                                                     Guid[] ids,
                                                                     int orderId,
                                                                     OrderDetail[] items)
        {
            var desc = string.Join(Environment.NewLine, items.Select(i => $"{i.ProductTitle} ({i.ProductUnit}) ×{i.Quantity}"));
            var n = new Notification
            {
                TitleAr = $"تم إلغاء الطلب #{orderId}",
                TitleEn = $"Order cancelled #{orderId}",
                TitleTr = $"Siparişiniz iptal edildi #{orderId}",
                TextAr = desc,
                TextEn = desc,
                TextTr = desc,
                //Topic = $"Order_{orderId}",
                Url = $"{AppDomainHelper.DashboardUrl}/Orders/ItemsNotFound/{orderId}",
                NotificationType = NotificationType.Order
            };
            await service.SendPushNotification(n, ids);
        }
        public static async Task SendCustomerOrderRejected(this INotificationService service,
                                                                Guid[] ids,
                                                                int orderId,
                                                                string merchantTitle = null,
                                                                string reason = null)
        {
            var mTitle = !string.IsNullOrWhiteSpace(merchantTitle) ? merchantTitle : "المتجر";
            var titleAr = $"تم رفض الطلب #{orderId}";
            var titleEn = $"Order #{orderId} declined";
            var titleTr = $"Sipariş #{orderId} reddedildi";

            var textAr = string.IsNullOrWhiteSpace(reason)
                ? $"نعتذر منك، لقد اعتذر {mTitle} عن قبول طلبك."
                : $"نعتذر منك، لقد اعتذر {mTitle} عن قبول طلبك. السبب: {reason}";

            var textEn = string.IsNullOrWhiteSpace(reason)
                ? $"We apologize, {mTitle} declined your order."
                : $"We apologize, {mTitle} declined your order. Reason: {reason}";

            var textTr = string.IsNullOrWhiteSpace(reason)
                ? $"Özür dileriz, {mTitle} siparişinizi reddetti."
                : $"Özür dileriz, {mTitle} siparişinizi reddetti. Sebep: {reason}";

            var n = new Notification
            {
                TitleAr = titleAr,
                TitleEn = titleEn,
                TitleTr = titleTr,
                TextAr = textAr,
                TextEn = textEn,
                TextTr = textTr,
                Url = $"{AppDomainHelper.DashboardUrl}/Orders/Rejected/{orderId}",
                NotificationType = NotificationType.Order
            };
            await service.SendPushNotification(n, ids);
        }
        public static async Task SendAdminMerchantDecision(this INotificationService service,
                                                           Guid[] adminIds,
                                                           int orderId,
                                                           bool accepted,
                                                           string merchantTitle,
                                                           string reason = null)
        {
            var merchant = string.IsNullOrWhiteSpace(merchantTitle) ? "المتجر" : merchantTitle;
            var textAr = accepted
                ? $"وافق {merchant} على الطلب #{orderId}. بانتظار أن ينهي التاجر التجهيز ويحدد الطلب كجاهز."
                : $"رفض {merchant} الطلب #{orderId}." + (string.IsNullOrWhiteSpace(reason) ? string.Empty : $" السبب: {reason}");
            var n = new Notification
            {
                TitleAr = accepted ? "وافق التاجر على الطلب" : "رفض التاجر الطلب",
                TitleEn = accepted ? "Merchant accepted order" : "Merchant rejected order",
                TitleTr = accepted ? "Satıcı siparişi kabul etti" : "Satıcı siparişi reddetti",
                TextAr = textAr,
                TextEn = textAr,
                TextTr = textAr,
                Url = $"{AppDomainHelper.DashboardUrl}/orders",
                NotificationType = NotificationType.Order
            };
            await service.SendPushNotification(n, adminIds);
        }

        public static async Task SendAdminOrderReadyForAssignment(this INotificationService service,
                                                                  Guid[] adminIds,
                                                                  int orderId,
                                                                  string merchantTitle)
        {
            var merchant = string.IsNullOrWhiteSpace(merchantTitle) ? "المتجر" : merchantTitle;
            var text = $"الطلب #{orderId} أصبح جاهزاً لدى {merchant}. عيّن مندوب توصيل لاستلامه.";
            var n = new Notification
            {
                TitleAr = "طلب جاهز لتعيين مندوب",
                TitleEn = "Order ready for courier assignment",
                TitleTr = "Sipariş kurye ataması için hazır",
                TextAr = text,
                TextEn = text,
                TextTr = text,
                Url = $"{AppDomainHelper.DashboardUrl}/orders",
                NotificationType = NotificationType.Order
            };
            await service.SendPushNotification(n, adminIds);
        }

        public static async Task SendAdminNewOrder(this INotificationService service,
                                                   Guid[] adminIds,
                                                   int orderId,
                                                   bool awaitsMerchant)
        {
            var textAr = awaitsMerchant
                ? $"الطلب #{orderId} من متجر خارجي. بانتظار قرار التاجر ولا يجب تعيين مندوب قبل أن يصبح جاهزاً."
                : $"الطلب #{orderId} من جيتك ماركت وبانتظار قرار الإدارة والتجهيز.";
            var n = new Notification
            {
                TitleAr = awaitsMerchant ? "طلب خارجي جديد" : "طلب جيتك ماركت جديد",
                TitleEn = awaitsMerchant ? "New external merchant order" : "New JTAK Market order",
                TitleTr = "Yeni sipariş",
                TextAr = textAr,
                TextEn = textAr,
                TextTr = textAr,
                Url = $"{AppDomainHelper.DashboardUrl}/orders",
                NotificationType = NotificationType.Order
            };
            await service.SendPushNotification(n, adminIds);
        }
        public static async Task SendCustomerOrderItemsChanged(this INotificationService service,
                                                                    Guid[] ids,
                                                                    int orderId,
                                                                    OrderDetail[] items)
        {
            var desc = string.Join(Environment.NewLine, items.Select(i => $"{i.ProductTitle} ({i.ProductUnit}) ×{i.Quantity}"));
            var n = new Notification
            {
                TitleAr = $"الموافقة على تعديل طلبك #{orderId}",
                TitleEn = $"Order change pending approval #{orderId}",
                TitleTr = $"Siparişiniz kabul beklyior #{orderId}",
                TextAr = desc,
                TextEn = desc,
                TextTr = desc,
                //Topic = $"Order_{orderId}",
                Url = $"{AppDomainHelper.DashboardUrl}/Orders/ItemsChanged/{orderId}",
                NotificationType = NotificationType.Order
            };
            await service.SendPushNotification(n, ids);
        }
        public static async Task SendShippingStarted(this INotificationService service,
                                                          Guid[] ids,
                                                          int orderId,
                                                          OrderDetail[] items)
        {
            var desc = string.Join(Environment.NewLine, items.Select(i => $"{i.ProductTitle} ({i.ProductUnit}) ×{i.Quantity}"));
            var n = new Notification
            {
                TitleAr = $"طلبك في طريقه إليك! #{orderId}",
                TitleEn = $"Your order is on the way! #{orderId}",
                TitleTr = $"Siparişiniz yolunda! #{orderId}",
                TextAr = desc,
                TextEn = desc,
                TextTr = desc,
                //Topic = $"Order_{orderId}",
                Url = $"{AppDomainHelper.DashboardUrl}/Orders/ShippingStarted/{orderId}",
                NotificationType = NotificationType.Order
            };
            await service.SendPushNotification(n, ids);
        }
        public static async Task SendCustomerOrderDelivered(this INotificationService service,
                                                          Guid[] ids,
                                                          int orderId)
        {
            var n = new Notification
            {
                TitleAr = $"تم تسليم طلبك بنجاح! #{orderId}",
                TitleEn = $"Your order was delivered successfully! #{orderId}",
                TitleTr = $"Siparişiniz başarıyla teslim edildi! #{orderId}",
                TextAr = "شكراً لاختيارك تطبيق جيتك. نتمنى لك تجربة ممتعة!",
                TextEn = "Thank you for choosing JTAK. We hope you enjoy it!",
                TextTr = "JTAK'ı tercih ettiğiniz için teşekkür ederiz!",
                Url = $"{AppDomainHelper.DashboardUrl}/Orders/Delivered/{orderId}",
                NotificationType = NotificationType.Order
            };
            await service.SendPushNotification(n, ids);
        }
        public static async Task SendPaymentRecived(this INotificationService service,
                                                          Guid[] ids,
                                                          int paymentId,
                                                          decimal amount)
        {
            var desc = $"تم استلام مبلغ وقدره ({amount:0.00})";
            var n = new Notification
            {
                TitleAr = $"تم استلام مبلغ",
                TitleEn = $"Amount was recived",
                TitleTr = $"Alınan miktar",
                TextAr = desc,
                TextEn = desc,
                TextTr = desc,
                //Topic = $"Order_{orderId}",
                Url = $"{AppDomainHelper.DashboardUrl}/Payment/Recived/{paymentId}",
                NotificationType = NotificationType.Order
            };
            await service.SendPushNotification(n, ids);
        }
        public static async Task SendNewSettlementRequest(this INotificationService service,
                                                          Guid[] adminIds,
                                                          string requestNumber,
                                                          string requesterName,
                                                          decimal amount,
                                                          bool isMerchant)
        {
            var typeAr = isMerchant ? "تاجر" : "مندوب توصيل";
            var typeEn = isMerchant ? "merchant" : "delivery captain";
            var n = new Notification
            {
                TitleAr = $"طلب تسوية جديد من {typeAr}",
                TitleEn = $"New {typeEn} settlement request",
                TitleTr = "Yeni mutabakat talebi",
                TextAr = $"{requesterName} أرسل طلب التسوية {requestNumber} بمبلغ {amount:N0} ل.س.",
                TextEn = $"{requesterName} submitted settlement {requestNumber} for {amount:N0} SYP.",
                TextTr = $"{requesterName}, {amount:N0} SYP tutarında mutabakat talebi gönderdi.",
                Url = $"{AppDomainHelper.DashboardUrl}/reconciliation",
                NotificationType = NotificationType.Order
            };
            await service.SendPushNotification(n, adminIds);
        }

        public static async Task SendSettlementRequestStatus(this INotificationService service,
                                                             Guid[] userIds,
                                                             string requestNumber,
                                                             decimal amount,
                                                             string status,
                                                             string reason = null)
        {
            var isCompleted = string.Equals(status, "Completed", StringComparison.OrdinalIgnoreCase);
            var isApproved = string.Equals(status, "Approved", StringComparison.OrdinalIgnoreCase);
            var titleAr = isCompleted ? "تمت التسوية بنجاح" : isApproved ? "تم قبول طلب التسوية" : "تم رفض طلب التسوية";
            var titleEn = isCompleted ? "Settlement completed" : isApproved ? "Settlement approved" : "Settlement rejected";
            var textAr = isCompleted
                ? $"تم إتمام الطلب {requestNumber} بقيمة {amount:N0} ل.س."
                : isApproved
                    ? $"تم قبول الطلب {requestNumber} بقيمة {amount:N0} ل.س وهو بانتظار تأكيد الاستلام."
                    : $"تم رفض الطلب {requestNumber}." + (string.IsNullOrWhiteSpace(reason) ? string.Empty : $" السبب: {reason}");
            var n = new Notification
            {
                TitleAr = titleAr,
                TitleEn = titleEn,
                TitleTr = titleEn,
                TextAr = textAr,
                TextEn = textAr,
                TextTr = textAr,
                Url = $"{AppDomainHelper.DashboardUrl}/Settlement/{requestNumber}",
                NotificationType = NotificationType.Order
            };
            await service.SendPushNotification(n, userIds);
        }
        //public static async Task SendOrderChanged(this INotificationService service,
        //                                               Guid[] ids,
        //                                               int orderId,
        //                                               OrderStatus oldStatus,
        //                                               OrderStatus status)
        //{
        //    var n = new Notification
        //    {
        //        TitleAr = $"تم تغيير حالة الطلب من '{oldStatus.ToLocalizedName()}' إلى '{status.ToLocalizedName()}'",
        //        TitleEn = $"The order status changed from '{oldStatus.ToLocalizedName()}' to '{status.ToLocalizedName()}'",
        //        TitleTr = $"Talab durumu değiştirdi '{oldStatus.ToLocalizedName()}' => '{status.ToLocalizedName()}'",
        //        TextAr = "من أجل الطلب #{orderId}",
        //        TextEn = "For order #{orderId}",
        //        TextTr = " taleb no: #{orderId}",
        //        Topic = "Orders",
        //        Url = $"{AppDomainHelper.DashboardUrl}/Orders/{orderId}",
        //        NotificationType = NotificationType.Order
        //    };
        //    await service.SendPushNotification(n, ids);
        //}
    }
}
