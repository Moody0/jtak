namespace App.ApiModels
{
    public class DashboardVm
    {
        public int ProductsCount { get; set; }
        public int UsersCount { get; set; }
        public int OrdersCount { get; set; }
        public int BillsCount { get; set; }
        public long TotalOrdersValue { get; set; }
        public long MerchantOrdersValue { get; set; }
        public long JTakOrdersValue { get; set; }
        public long JTakAdditionalOrdersValue { get; set; }
        public TopProduct[] TopProducts { get; set; }
    }

    public class TopProduct
    {

        public int ProductId { get; set; }
        public string ProductName { get; set; }
        public int Count { get; set; }
    }
}
