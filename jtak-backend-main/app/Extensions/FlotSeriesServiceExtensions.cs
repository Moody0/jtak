namespace App.Extensions
{
    public static class FlotSeriesServiceExtensions
    {
        //public static FlotSeriesVm<object> GetSeries(this IDeliverableService service,
        //    DateTime? since = null,
        //    string label = "Deliverables",
        //    string color = "#1f92fe")
        //{
        //    since = since ?? DateTime.Now.Date.AddDays(-10);
        //    var dbresult = service.Queryable()
        //        .Where(x => x.CreatedDate >= since)
        //        .GroupBy(x => x.DeliveryDate.DayOfYear)
        //        .ToList();

        //    var data = new List<object[]>();

        //    for (var d = since; d <= DateTime.Now.Date; d = d.Value.AddDays(1))
        //    {
        //        var i = dbresult.FirstOrDefault(x => x.Key == d.Value.DayOfYear);
        //        data.Add(new object[] { d.Value.ToString("M/d"), i?.Count() ?? 0 });
        //    }
        //    return new FlotSeriesVm<object>()
        //    {
        //        label = label,
        //        color = color,
        //        data = data.ToArray()
        //    };
        //}

    }
}
