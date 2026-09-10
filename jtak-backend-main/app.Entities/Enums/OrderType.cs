namespace App.Shared.Entities.Enums
{
    //[JsonConverter(typeof(JsonStringEnumConverter))]
    public enum OrderType
    {
        StockIn = 0, // i.e Adding to vendor stock
        StockOut = 1 // i.e Removing from vendor stock to user stock
    }
}
