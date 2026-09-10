namespace App.ApiControllers.V1.Admin
{

    //[Route("api/v{version:apiVersion}/Admin/[controller]")]
    //[ApiVersion("1")]
    //[Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.AdminPermission))]
    //public class TestimonialsController : SolApiController
    //{
    //    private readonly ITestimonialService _service;
    //    private readonly IAppUnitOfWork _unitOfWork;
    //    private readonly ILogger _logger;
    //    private readonly IMapper _mapper;
    //
    //    public TestimonialsController(ITestimonialService service, IAppUnitOfWork unitOfWork, ILogger<TestimonialsController> logger, IMapper mapper)
    //    {
    //        _service = service;
    //        _unitOfWork = unitOfWork;
    //        _logger = logger;
    //        _mapper = mapper;
    //    }
    //
    //    /// <summary>
    //    /// Get a paged/filtered/ordered list of Testimonials
    //    /// </summary>
    //    /// <returns></returns>
    //    [HttpPost]
    //    [Route("DataTable")]
    //    public async Task<ActionResult<TableResponseModel<TestimonialDto>>> DataTable([FromBody] MetronicTable request)
    //    {
    //        var lang = System.Threading.Thread.CurrentThread.CurrentCulture.TwoLetterISOLanguageName;
    //        var list = await _service.ListMetronicTableQueryable(request, x => new TestimonialDto
    //        {
    //            Id = x.Id,
    //            Name = x.Translations.FirstOrDefault(t => t.Language == lang).Name ?? x.Translations.FirstOrDefault().Name,
    //            Photo = x.Translations.FirstOrDefault(t => t.Language == lang).Photo ?? x.Translations.FirstOrDefault().Photo,
    //            Text = x.Translations.FirstOrDefault(t => t.Language == lang).Text ?? x.Translations.FirstOrDefault().Text
    //        }, x => true, x => x.Translations);
    //        return list;
    //    }
    //
    //
    //    /// <summary>
    //    /// Create a new Testimonial
    //    /// </summary>
    //    /// <returns></returns>
    //    [HttpPost]
    //    public async Task<ActionResult<int>> Create(TestimonialDto item)
    //    {
    //        var entity = new Testimonial { };
    //        _service.Insert(entity);
    //        await _unitOfWork.SaveChangesAsync();
    //
    //        var trans = new TestimonialTranslation { CoreId = entity.Id, Name = item.Name, Text = item.Text, Photo = item.Photo };
    //        _service.Insert(trans);
    //        await _unitOfWork.SaveChangesAsync();
    //        _logger.LogInformation("Created New {0}", entity.GetType().Name);
    //
    //        return entity.Id;
    //    }
    //
    //    /// <summary>
    //    /// Edit a Testimonial
    //    /// </summary>
    //    /// <returns></returns>
    //    [HttpPut]
    //    [Route("{id}")]
    //    public async Task<ActionResult<int>> Edit(int id, TestimonialDto item)
    //    {
    //        var entity = await _service.FindAsync(id);
    //        if (entity == null) return BadRequest(ApiErr.Create("Not Found"));
    //
    //        var trans = entity.Translations.Current();
    //        if (trans == null)
    //        {
    //            _service.Insert(new TestimonialTranslation { CoreId = entity.Id, Name = item.Name, Text = item.Text, Photo = item.Photo });
    //        }
    //        else
    //        {
    //            trans.Name = item.Name;
    //            trans.Text = item.Text;
    //            trans.Photo = item.Photo;
    //            _service.Update(trans);
    //        }
    //
    //        _service.Update(entity);
    //        await _unitOfWork.SaveChangesAsync();
    //        _logger.LogInformation("Edited Testimonial {0} #{1}", entity.GetType().Name, entity.Id);
    //
    //        return entity.Id;
    //    }
    //
    //
    //    /// <summary>
    //    /// Delete a Testimonial
    //    /// </summary>
    //    /// <returns></returns>
    //    [HttpDelete]
    //    [Route("{id}")]
    //    public async Task<ActionResult<bool>> Delete(int id)
    //    {
    //        var entity = await _service.Queryable().Include(x => x.Translations).FirstOrDefaultAsync(x => x.Id == id);
    //        if (entity == null)
    //            return BadRequest(ApiErr.Create("Not Found"));
    //
    //        _service.Delete(entity);
    //        await _unitOfWork.SaveChangesAsync();
    //        _logger.LogInformation("Deleted Testimonial {0} #{1}", entity.GetType().Name, entity.Id);
    //
    //        return true;
    //    }
    //}
}
