namespace App.Extensions
{
    public static class MyListGridExtensions
    {

        //public static async Task<DataTablesJsonResult> MyListGridAsync(this IArticleService _service,
        //    IMapper mapper,
        //    IDataTablesRequest request,
        //    Guid? uid,
        //    int[] leadingTeamIds,
        //    int[] leadingCommitteeIds)
        //{
        //    if (level == DataTableViewLevel.All)
        //    {
        //        return await _service.ListGridAsync(request, x => mapper.Map<ArticleDto>(x),
        //                                                            x => x.ArticleType == type &&
        //                                                                 ((x.AuthorId == uid) || (x.TeamId.HasValue && leadingTeamIds.Contains(x.TeamId.Value)) || (x.CommitteeId.HasValue && leadingCommitteeIds.Contains(x.CommitteeId.Value))),
        //                                                            x => x.Translations,
        //                                                            x => x.Author,
        //                                                            x => x.Team.Translations,
        //                                                            x => x.Committee.Translations,
        //                                                            x => x.Category.Translations);
        //    }
        //    else if (level == DataTableViewLevel.Mine)
        //    {
        //        return await _service.ListGridAsync(request, x => mapper.Map<ArticleDto>(x),
        //                                                            x => x.ArticleType == type &&
        //                                                                 (x.AuthorId == uid),
        //                                                            x => x.Translations,
        //                                                            x => x.Author,
        //                                                            x => x.Team.Translations,
        //                                                            x => x.Committee.Translations,
        //                                                            x => x.Category.Translations);
        //    }
        //    else /*if (id == DataTableViewLevel.Team)*/
        //    {
        //        return await _service.ListGridAsync(request, x => mapper.Map<ArticleDto>(x),
        //                                                            x => x.ArticleType == type &&
        //                                                                 (x.TeamId.HasValue && leadingTeamIds.Contains(x.TeamId.Value)),
        //                                                            x => x.Translations,
        //                                                            x => x.Author.MemberOfTeams,
        //                                                            x => x.Team.Translations,
        //                                                            x => x.Committee.Translations,
        //                                                            x => x.Category.Translations);
        //    }
        //}
        //
        //public static async Task<DataTablesJsonResult> MyListGridAsync(this IEventService _service,
        //    IMapper mapper, 
        //    IDataTablesRequest request,
        //    Guid? uid,
        //    int[] leadingTeamIds,
        //    int[] leadingCommitteeIds,
        //    DataTableViewLevel level)
        //{
        //    if (level == DataTableViewLevel.All)
        //    {
        //        return await _service.ListGridAsync(request, x => mapper.Map<EventDto>(x),
        //                                                            x => ((x.AuthorId == uid) || (x.TeamId.HasValue && leadingTeamIds.Contains(x.TeamId.Value))),
        //                                                            x => x.Translations,
        //                                                            x => x.Author,
        //                                                            x => x.Team.Translations,
        //                                                            x => x.Category.Translations);
        //    }
        //    else if (level == DataTableViewLevel.Mine)
        //    {
        //        return await _service.ListGridAsync(request, x => mapper.Map<EventDto>(x),
        //                                                            x => (x.AuthorId == uid),
        //                                                            x => x.Translations,
        //                                                            x => x.Author,
        //                                                            x => x.Team.Translations,
        //                                                            x => x.Category.Translations);
        //    }
        //    else /*if (id == DataTableViewLevel.Team)*/
        //    {
        //        return await _service.ListGridAsync(request, x => mapper.Map<EventDto>(x),
        //                                                            x => (x.TeamId.HasValue && leadingTeamIds.Contains(x.TeamId.Value)),
        //                                                            x => x.Translations,
        //                                                            x => x.Author.MemberOfTeams,
        //                                                            x => x.Team.Translations,
        //                                                            x => x.Category.Translations);
        //    }
        //}
    }
}
