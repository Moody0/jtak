using App.ApiModels;
using App.Shared.Data.App;
using AutoMapper;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Modules.Catalog.Entities;
using Modules.Catalog.Services;
using System.Threading.Tasks;

namespace App.ApiControllers.V1.Customer
{
    [Route("api/v{version:apiVersion}/Customer/[controller]")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [ApiVersion("1")]
    public class ProductCategoriesController : SolApiController
    {
        private readonly IProductCategoryService _service;
        private readonly IAppUnitOfWork _unitOfWork;
        private readonly ILogger _logger;
        private readonly IMapper _mapper;

        public ProductCategoriesController(IProductCategoryService service,
            IAppUnitOfWork unitOfWork,
            ILogger<ProductCategoriesController> logger, IMapper mapper)
        {
            _service = service;
            _unitOfWork = unitOfWork;
            _logger = logger;
            _mapper = mapper;
        }


        /// <summary>
        /// Get a list of all ProductCategories
        /// </summary>
        /// <returns></returns>
        [HttpGet]
        public async Task<ProductCategoryDto[]> Get() =>
            await _service.GetProductCategoriesTree();
    }
}
