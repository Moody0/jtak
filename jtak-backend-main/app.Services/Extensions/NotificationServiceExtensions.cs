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
