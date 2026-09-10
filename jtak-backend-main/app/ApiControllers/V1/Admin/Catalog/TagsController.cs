namespace App.ApiControllers.V1.Admin
{
    //[Route("api/v{version:apiVersion}/Admin/[controller]")]
    //[ApiVersion("1")]
    //[Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.AdminPermission))]
    //public class TagsController : SolApiController
    //{
    //    private readonly ITagService _service;
    //    private readonly IAppUnitOfWork _unitOfWork;
    //    private readonly ILogger _logger;
    //    private readonly IMapper _mapper;
    //
    //    public TagsController(ITagService service, IAppUnitOfWork unitOfWork, ILogger<TagsController> logger, IMapper mapper)
    //    {
    //        _service = service;
    //        _unitOfWork = unitOfWork;
    //        _logger = logger;
    //        _mapper = mapper;
    //    }
    //
    //    /// <summary>
    //    /// Get a paged/filtered/ordered list of Tags
    //    /// </summary>
    //    /// <returns></returns>
    //    [HttpPost]
    //    [Route("DataTable")]
    //    public async Task<ActionResult<TableResponseModel<TagDto>>> DataTable([FromBody] MetronicTable request) =>
    //        await _service.ListMetronicTableQueryable(request, x => new TagDto
    //        {
    //            Id = x.Id,
    //            NameAr = x.NameAr,
    //            NameEn = x.NameEn,
    //            NameTr = x.NameTr,
    //            Photo = x.Photo
    //        }, x => true);
    //
    //    /// <summary>
    //    /// Create a new Tag
    //    /// </summary>
    //    /// <returns></returns>
    //    [HttpPost]
    //    public async Task<ActionResult<int>> Create(TagDto item)
    //    {
    //        var entity = new Tag { Photo = item.Photo, NameAr = item.NameAr, NameTr = item.NameTr, NameEn = item.NameEn };
    //        _service.Insert(entity);
    //        await _unitOfWork.SaveChangesAsync();
    //        _logger.LogInformation("Created New {0}", entity.GetType().Name);
    //
    //        return entity.Id;
    //    }
    //
    //
    //    /// <summary>
    //    /// Get a list of all Tags
    //    /// </summary>
    //    /// <returns></returns>
    //    [HttpGet]
    //    public async Task<TagDto[]> Get()
    //    {
    //        var list = await _service.Queryable()
    //                                 .Select(x => _mapper.Map<TagDto>(x))
    //                                 .ToArrayAsync();
    //        return list;
    //    }
    //
    //    /// <summary>
    //    /// Get a specific Tag
    //    /// </summary>
    //    /// <returns></returns>
    //    [HttpGet]
    //    [Route("{id}")]
    //    public async Task<TagDto> Get(int id)
    //    {
    //        var entity = await _service.Queryable().FirstOrDefaultAsync(x => x.Id == id);
    //        return _mapper.Map<TagDto>(entity);
    //    }
    //
    //    /// <summary>
    //    /// Edit a Tag
    //    /// </summary>
    //    /// <returns></returns>
    //    [HttpPut]
    //    [Route("{id}")]
    //    public async Task<ActionResult<int>> Edit(int id, TagDto item)
    //    {
    //        var entity = await _service.FindAsync(id);
    //        if (entity == null) return BadRequest(ApiErr.Create("Not Found"));
    //
    //        entity.NameAr = item.NameAr;
    //        entity.NameTr = item.NameTr;
    //        entity.NameEn = item.NameEn;
    //        entity.Photo = item.Photo;
    //
    //        _service.Update(entity);
    //        await _unitOfWork.SaveChangesAsync();
    //        _logger.LogInformation("Edited Tag {0} #{1}", entity.GetType().Name, entity.Id);
    //
    //        return entity.Id;
    //    }
    //
    //
    //    /// <summary>
    //    /// Edit a Tag
    //    /// </summary>
    //    /// <returns></returns>
    //    [HttpDelete]
    //    [Route("{id}")]
    //    public async Task<ActionResult<bool>> Delete(int id)
    //    {
    //        var entity = await _service.Queryable().Include(x => x.Tags).FirstOrDefaultAsync(x => x.Id == id);
    //        if (entity == null) return BadRequest(ApiErr.Create("Not Found"));
    //        if (entity.Tags.Any()) return BadRequest(ApiErr.Create("Edit FoodItems First"));
    //
    //        _service.Delete(entity);
    //        await _unitOfWork.SaveChangesAsync();
    //        _logger.LogInformation("Deleted Tag {0} #{1}", entity.GetType().Name, entity.Id);
    //
    //        return true;
    //    }
    //}
}
