using URF.Core.Abstractions.Services;
using URF.Core.Services;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using System.Linq;
using AutoMapper;
using App.Shared.Entities.Domain;
using App.Shared.Data.App;
using App.Shared.Data.MultiContext;

namespace App.Shared.Services
{
    public interface IFaqService : IService<Faq>
    {
        Task<FaqLiteDto[]> GetList();
    }

    public class FaqService : Service<Faq>, IFaqService
    {
        private readonly IMapper _mapper;
        public FaqService(ITrackableRepository<Faq, AppDbContext> repository, IMapper mapper) : base(repository)
        {
            _mapper = mapper;
        }

        public async Task<FaqLiteDto[]> GetList() =>
            (await Queryable().ToListAsync()).Select(x => _mapper.Map<FaqLiteDto>(x)).ToArray();

    }
}