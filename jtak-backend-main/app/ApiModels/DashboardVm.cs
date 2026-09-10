namespace App.ApiModels
{
    public class DashboardVm
    {
        public int ProductsCount { get; set; }
        public int UsersCount { get; set; }
        public int OrdersCount { get; set; }
        public int BillsCount { get; set; }
        public int TotalOrdersValue { get; set; }
        public int MerchantOrdersValue { get; set; }
        public int JTakOrdersValue { get; set; }
        public int JTakAdditionalOrdersValue { get; set; }
        public TopProduct[] TopProducts { get; set; }
    }

    public class TopProduct
    {

        public int ProductId { get; set; }
        public string ProductName { get; set; }
        public int Count { get; set; }
    }
}
