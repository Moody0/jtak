//using App.Shared.Services.Options;
//using System;
//using System.Text.Json.Serialization;

//namespace App.Shared.Services.Model.WeePay
//{
//    public class WeePayInit
//    {
//        [JsonPropertyName("Auth")]
//        public WeepayOptions Auth { get; set; }

//        [JsonPropertyName("Data")]
//        public OrderData Data { get; set; }

//        [JsonPropertyName("Customer")]
//        public Customer Customer { get; set; }

//        [JsonPropertyName("BillingAddress")]
//        public CustomerAddress BillingAddress { get; set; }

//        [JsonPropertyName("ShippingAddress")]
//        public CustomerAddress ShippingAddress { get; set; }

//        [JsonPropertyName("Products")]
//        public Product[] Products { get; set; }
//    }


//    public class CustomerAddress
//    {
//        [JsonPropertyName("contactName")]
//        public string ContactName { get; set; }

//        [JsonPropertyName("address")]
//        public string Address { get; set; }

//        [JsonPropertyName("city")]
//        public string City { get; set; }

//        [JsonPropertyName("country")]
//        public string Country { get; set; }

//        [JsonPropertyName("zipCode")]
//        public string ZipCode { get; set; }
//    }

//    public class Customer
//    {
//        [JsonPropertyName("customerId")]

//        public string CustomerId { get; set; }

//        [JsonPropertyName("customerName")]
//        public string CustomerName { get; set; }

//        [JsonPropertyName("customerSurname")]
//        public string CustomerSurname { get; set; }

//        [JsonPropertyName("gsmNumber")]
//        public string GsmNumber { get; set; }

//        [JsonPropertyName("email")]
//        public string Email { get; set; }

//        [JsonPropertyName("identityNumber")]
//        public string IdentityNumber { get; set; }

//        [JsonPropertyName("city")]
//        public string City { get; set; }

//        [JsonPropertyName("country")]
//        public string Country { get; set; }
//    }

//    public class OrderData
//    {
//        [JsonPropertyName("orderId")]
//        public long OrderId { get; set; }

//        [JsonPropertyName("currency")]
//        public string Currency { get; set; }

//        [JsonPropertyName("locale")]
//        public string Locale { get; set; }

//        [JsonPropertyName("paidPrice")]
//        public string PaidPrice { get; set; }

//        [JsonPropertyName("ipAddress")]
//        public string IpAddress { get; set; }

//        [JsonPropertyName("cardHolderName")]
//        public string CardHolderName { get; set; }

//        [JsonPropertyName("cardNumber")]
//        public string CardNumber { get; set; }

//        [JsonPropertyName("expireMonth")]

//        public string ExpireMonth { get; set; }

//        [JsonPropertyName("expireYear")]
//        public string ExpireYear { get; set; }

//        [JsonPropertyName("cvcNumber")]
//        public string CvcNumber { get; set; }

//        [JsonPropertyName("installmentNumber")]
//        public long InstallmentNumber { get; set; }

//        [JsonPropertyName("description")]
//        public string Description { get; set; }

//        [JsonPropertyName("callBackUrl")]
//        public string CallBackUrl { get; set; }
//    }

//    public class Product
//    {
//        [JsonPropertyName("productId")]
//        public string ProductId { get; set; }

//        [JsonPropertyName("name")]
//        public string Name { get; set; }

//        [JsonPropertyName("productPrice")]
//        public double ProductPrice { get; set; }

//        [JsonPropertyName("itemType")]
//        public string ItemType { get; set; }
//    }

//    public partial class ThreedsInitialize
//    {
//        [JsonPropertyName("status")]
//        public string Status { get; set; }

//        [JsonPropertyName("threeDSecureUrl")]
//        public string ThreeDSecureUrl { get; set; }

//        [JsonPropertyName("errorCode")]
//        public string ErrorCode { get; set; }

//        [JsonPropertyName("message")]
//        public string Message { get; set; }
//        public bool IsSuccess => Status == "success";
//    }

//    public partial class CallBackRequest
//    {
//        [JsonPropertyName("paymentStatus")]
//        public bool PaymentStatus { get; set; }

//        [JsonPropertyName("secretKey")]
//        public string SecretKey { get; set; }

//        [JsonPropertyName("paymentId")]
//        public string PaymentId { get; set; }

//        [JsonPropertyName("errorCode")]
//        public string ErrorCode { get; set; }

//        [JsonPropertyName("message")]
//        public string Message { get; set; }
//    }
//}