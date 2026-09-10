namespace App.Areas.Admin.Controllers
{
    //[Area("Admin")]
    //public class CityAreasController : BaseController
    //{
    //    private ICityAreaService _service;
    //    private ICityService _cityService;
    //    private IWebHostEnvironment _env;
    //    public CityAreasController(ICityAreaService service,
    //                            ICityService cityService,
    //                            IWebHostEnvironment env,
    //                            IMapper mapper,
    //                            ILogger<CityAreasController> logger,
    //                            IUnitOfWork unitOfWork,
    //                            UserManager<AppUser> userManager) : base(unitOfWork, mapper, logger, userManager)
    //    {
    //        _service = service;
    //        _cityService = cityService;
    //        _env = env;
    //    }
    //
    //    #region Index
    //    public IActionResult Index()
    //    {
    //        ViewBag.Title = _Nav.CityAreas;
    //        return View();
    //    }
    //    [HttpPost]
    //    public async Task<ActionResult<DataTablesResponse>> Index(DataTablesRequest request)
    //    {
    //        var lang = CultureInfo.CurrentCulture.TwoLetterISOLanguageName;
    //        return await _service.ListGridAsync(request, x => new CityAreaDto
    //        {
    //            Id = x.Id,
    //            City = lang == "ar" ? x.City.TitleAr : lang == "en" ? x.City.TitleEn : x.City.TitleTr,
    //            TitleAr = x.TitleAr,
    //            TitleEn = x.TitleEn,
    //            TitleTr = x.TitleTr,
    //            CityId = x.CityId
    //        }, x => true, x => x.City);
    //    }
    //    #endregion
    //
    //    #region Create
    //    public IActionResult Create()
    //    {
    //        ViewBag.Title = _Common.Create;
    //        InitViewBags();
    //        return View(new CityAreaDto() { });
    //    }
    //
    //    [HttpPost]
    //    [ValidateAntiForgeryToken]
    //    public async Task<IActionResult> Create(CityAreaDto vm)
    //    {
    //        if (ModelState.IsValid)
    //        {
    //            try
    //            {
    //                var entity = new CityArea { TitleAr = vm.TitleAr, TitleEn = vm.TitleEn, TitleTr = vm.TitleTr, CityId = vm.CityId };
    //                _service.Insert(entity);
    //                await UnitOfWork.SaveChangesAsync();
    //
    //                Logger.LogInformation("Created New {0}", vm.GetType().Name);
    //                return RedirectToAction(nameof(Index));
    //            }
    //            catch (DbUpdateException e)
    //            {
    //                ModelState.AddModelError("", _env.IsDevelopment() ? e.ToString() : _Common.Err_TryLater);
    //                Logger.LogError(e, e.ToString());
    //            }
    //        }
    //        ViewBag.Title = _Common.Create;
    //        InitViewBags(vm);
    //        return View(vm);
    //    }
    //    #endregion
    //
    //    #region Edit
    //    public async Task<IActionResult> Edit(int? id)
    //    {
    //        if (id == null) return NotFound();
    //        var target = await _service.FindAsync(id.Value);
    //        if (target == null) return NotFound();
    //
    //        ViewBag.Title = _Common.Edit;
    //        var model = Mapper.Map<CityAreaDto>(target);
    //        InitViewBags(model);
    //        return View(model);
    //    }
    //
    //    [HttpPost]
    //    [ValidateAntiForgeryToken]
    //    public async Task<IActionResult> Edit(int id, CityAreaDto vm)
    //    {
    //        if (vm.Id != id) return NotFound();
    //        var target = await _service.FindAsync(id);
    //        if (target == null) return NotFound();
    //
    //        if (ModelState.IsValid)
    //        {
    //            try
    //            {
    //                target.TitleAr = vm.TitleAr;
    //                target.TitleEn = vm.TitleEn;
    //                target.TitleTr = vm.TitleTr;
    //                _service.Update(target);
    //                await UnitOfWork.SaveChangesAsync();
    //                Logger.LogInformation("Edit {0} #{1}", target.GetType().Name, target.Id);
    //
    //                return RedirectToAction(nameof(Index));
    //            }
    //            catch (DbUpdateConcurrencyException e)
    //            {
    //                ModelState.AddModelError("", _env.IsDevelopment() ? e.ToString() : _Common.Err_TryLater);
    //                Logger.LogError(e, e.ToString());
    //            }
    //        }
    //        ViewBag.Title = _Common.Edit;
    //        InitViewBags(vm);
    //        return View(vm);
    //    }
    //    #endregion
    //
    //    #region Delete
    //    [HttpPost, ActionName("Delete")]
    //    public async Task<IActionResult> DeleteConfirmed(int? id)
    //    {
    //        if (id == null) return NotFound();
    //        try
    //        {
    //            var target = await _service.FindAsync(id.Value);
    //            await _service.DeleteAsync(id.Value);
    //            await UnitOfWork.SaveChangesAsync();
    //            Logger.LogInformation("Deleted {0} #{1}", target.GetType().Name, target.Id);
    //        }
    //        catch (DbUpdateException e)
    //        {
    //            ModelState.AddModelError("", _env.IsDevelopment() ? e.ToString() : _Common.Err_TryLater);
    //            Logger.LogError(e, e.ToString());
    //        }
    //        return RedirectToAction(nameof(Index));
    //    }
    //    #endregion
    //
    //    private void InitViewBags(CityAreaDto vm = null)
    //    {
    //        ViewBag.CityId = _cityService.GetSelectList(vm?.CityId);
    //    }
    //
    //    public async Task<IActionResult> Search(int id, string q = "")
    //    {
    //        try
    //        {
    //            q = StringExtensions.Normalize(q);
    //            var empty = string.IsNullOrEmpty(q?.Trim().ToLower());
    //            if (empty) return Json(new Select2List
    //            {
    //                results = (await _service.Queryable()
    //                                         .Where(x => (int)x.CityId == id)
    //                                         .Take(6)
    //                                         .ToArrayAsync())
    //                                         .Select(x => new Select2ListItem { text = x.Title, id = x.Id.ToString() }).ToArray()
    //            });
    //            var result = new Select2List
    //            {
    //                results = (await _service.Queryable()
    //                                        .Where(x => (int)x.CityId == id).ToArrayAsync())
    //                                        .Where(x => StringExtensions.Normalize(x.Title).Contains(q))
    //                                        .Select(x => new Select2ListItem { text = x.Title, id = x.Id.ToString() })
    //                                        .Take(6)
    //                                        .ToArray()
    //            };
    //            return Json(result);
    //        }
    //        catch (Exception e)
    //        {
    //            return Json(new Select2List { results = new[] { new Select2ListItem { text = e.ToString(), id = "" } } });
    //        }
    //    }
    //}
}
