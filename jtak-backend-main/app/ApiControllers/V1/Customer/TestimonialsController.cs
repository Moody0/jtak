using App.ApiModels;
using App.Shared.Entities.Domain;
using App.Shared.Services.Domain;
using App.Shared.Data.App;
using AutoMapper;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using System.Linq;
using System.Linq.Dynamic.Core;
using System.Threading.Tasks;

namespace App.ApiControllers.V1.Customer
{
    [Route("api/v{version:apiVersion}/Customer/[controller]")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [ApiVersion("1")]
    public class TestimonialsController : SolApiController
    {
        private readonly ITestimonialService _service;
        private readonly IAppUnitOfWork _unitOfWork;
        private readonly ILogger _logger;
        private readonly IMapper _mapper;

        public TestimonialsController(ITestimonialService service, IAppUnitOfWork unitOfWork, ILogger<TestimonialsController> logger, IMapper mapper)
        {
            _service = service;
            _unitOfWork = unitOfWork;
            _logger = logger;
            _mapper = mapper;
        }

        /// <summary>
        /// Get a list of all Testimonials
        /// </summary>
        /// <returns></returns>
        [HttpGet]
        public async Task<TestimonialDto[]> Get()
        {
            var list = await _service.Queryable().Include(x => x.Translations).Select(x => _mapper.Map<TestimonialDto>(x)).ToArrayAsync();
            return list;
        }

        /// <summary>
        /// Get a specific Testimonial by id
        /// </summary>
        /// <returns></returns>
        [HttpGet]
        [Route("{id}")]
        public async Task<TestimonialDto> Get(int id)
        {
            var item = await _service.FindAsync(id);
            return _mapper.Map<TestimonialDto>(item);
        }
    }
}
