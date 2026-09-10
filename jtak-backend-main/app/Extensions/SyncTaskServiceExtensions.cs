namespace App.Extensions
{
    //public static class SyncTaskServiceExtensions
    //{
    //    public static int[] GetHoursSeries(this ISyncTaskService service, DateTime? since = null)
    //    {
    //        var date = since ?? DateTime.Now.AddHours(-23);
    //        var result = service.Queryable()
    //            .Where(x => x.SyncCompleteDate >= date)
    //            .GroupBy(x => x.SyncCompleteDate.Value.Hour)
    //            .Select(x => new { Hour = x.FirstOrDefault().SyncCompleteDate.Value.Hour, Count = x.Count() })
    //            .ToArray();
    //        var res = new List<int>();
    //        for (var i = date; i <= DateTime.Now; i = i.AddHours(1))
    //        {
    //            var dbr = result.FirstOrDefault(x => x.Hour == i.Hour);
    //            res.Add(dbr?.Count ?? 0);
    //        }

    //        return res.ToArray();
    //    }
    //    public static double SyncPercent(this ISyncTaskService service, DateTime? since = null)
    //    {
    //        since = since ?? DateTime.Now.AddHours(-23);
    //        var all = service.Queryable().Count(x => x.CreatedDate >= since);
    //        var synced = service.Queryable().Count(x => x.CreatedDate >= since && x.SyncCompleteDate != null);

    //        if (all == 0 || synced == 0) return 100;
    //        return synced * 100.0 / all;
    //    }
    //    public static long SyncedTasksSize(this ISyncTaskService service, DateTime? since = null)
    //    {
    //        since = since ?? DateTime.Now.AddHours(-23);
    //        return service.Queryable().Where(x => x.SyncCompleteDate >= since).Sum(x => x.SyncedBytes);
    //    }
    //}
}
