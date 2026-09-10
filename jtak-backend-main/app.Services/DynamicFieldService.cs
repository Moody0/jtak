using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Modules.Catalog.Entities.EAV;
using Solf.Base;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using URF.Core.Abstractions.Trackable;

namespace App.Shared.Services
{
    public interface IDynamicFieldService : ISolService<DynamicField, DynamicFieldDto>
    {

    }
    public class DynamicFieldService : SolService<DynamicField, DynamicFieldDto>, IDynamicFieldService
    {
        private readonly IMemoryCache _cache;
        public DynamicFieldService(ITrackableRepository<DynamicField> repository, IMemoryCache cache) : base(repository)
        {
            _cache = cache;
        }
        public async Task<Dictionary<int, DynamicFieldDto>> GetDynamicFields(int dfid) =>
            await _cache.GetValue($"DynamicFields_{dfid}", null,
                async () => await Repository.Queryable()
                                            .Select(x => new DynamicFieldDto
                                            {
                                                ControlType = x.ControlType,
                                                DisplayName = x.DisplayName,
                                                Id = x.Id,
                                                DisplayOrder = x.DisplayOrder,
                                                ProductCategoryId = x.ProductCategoryId,
                                                IsRequired = x.IsRequired,
                                                PotentialValues = x.PotentialValues
                                            })
                                            .ToDictionaryAsync(x => x.Id));
    }
}
