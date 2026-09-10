namespace App.ApiModels
{
    public class ProductSearchVm
    {
        public int Take { get; set; } = 9;
        public int Page { get; set; } = 0;
        public int? ProductCategoryId { get; set; }
        public string q { get; set; }
        //public OrderBy OrderBy { get; set; }
        public decimal? Lat { get; set; }
        public decimal? Lng { get; set; }
    }
    //[JsonConverter(typeof(JsonStringEnumConverter))]
    //public enum OrderBy {
    //    PriceAsc = 0,
    //    PriceDesc = 1,
    //    RateAsc = 2,
    //    RateDesc = 3
    //}
}
