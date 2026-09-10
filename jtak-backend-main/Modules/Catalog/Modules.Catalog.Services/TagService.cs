using App.Catalog.Data;
using App.Shared.Data.MultiContext;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Modules.Catalog.Entities;
using Solf.Base;
using System;
using System.Linq;
using System.Threading.Tasks;
using URF.Core.Abstractions.Trackable;

namespace Modules.Catalog.Services
{
    public interface ITagService : ISolService<Tag, TagDto>
    {
        /*
        Task SetTags(int id, string[] tags);
        */
        Task SetTags(int id, int[] tags);
    }
    public class TagService : SolService<Tag, TagDto>, ITagService
    {
        ITrackableRepository<Product> _productRepo;
        ITrackableRepository<Tag> _tagsRepo;
        ITrackableRepository<ProductTag> _foodItemTagRepo;
        ICatalogUnitOfWork _unitOfWork;
        ILogger _logger;
        public TagService(ICatalogUnitOfWork unitOfWork,
                                ILogger<TagService> logger,
                                ITrackableRepository<Product, CatalogDbContext> productRepo,
                                ITrackableRepository<Tag, CatalogDbContext> tagsRepo,
                                ITrackableRepository<ProductTag, CatalogDbContext> foodItemTagRepo) : base(tagsRepo)
        {
            _logger = logger;
            _tagsRepo = tagsRepo;
            _productRepo = productRepo;
            _foodItemTagRepo = foodItemTagRepo;
            _unitOfWork = unitOfWork;
        }

        public override IQueryable<Tag> Search(IQueryable<Tag> query, string keyword)
        {
            keyword = keyword?.Trim()?.ToLower();
            if (string.IsNullOrEmpty(keyword))
                return query;
            return query.Where(x => x.NameAr.ToLower().Contains(keyword) ||
                                    x.NameTr.ToLower().Contains(keyword) ||
                                    x.NameEn.ToLower().Contains(keyword));
        }
        /*
        public async Task SetTags(int id, string[] tags)
        {
            var foodItem = await _productRepo.Queryable().FirstOrDefaultAsync(x => x.Id == id);
            if (foodItem == null)
                return;

            // Clean tags
            tags = tags?.Select(x => x?.Trim()).Where(x => !string.IsNullOrEmpty(x)).Distinct().ToArray() ?? Array.Empty<string>();
            tags = tags.Length > 10 ? tags.Take(10).ToArray() : tags;
            var anyTags = tags.Length > 0;

            foodItem = await _productRepo.Queryable().Include(x => x.Tags).ThenInclude(x => x.Tag).FirstOrDefaultAsync(x => x.Id == id);
            var currentTags = foodItem.Tags.Select(x => x.Tag).ToArray();
            var currentTagStrings = currentTags.SelectMany(x => new[] { x.NameAr, x.NameTr, x.NameEn });

            // Link new tags
            var newTags = anyTags ? await _tagsRepo.Queryable()
                                                   .Where(x => !currentTagStrings.Contains(x.NameAr) && !currentTagStrings.Contains(x.NameTr) && !currentTagStrings.Contains(x.NameEn))
                                                   .ToArrayAsync() : Array.Empty<Tag>();

            foreach (var item in newTags)
                _foodItemTagRepo.Insert(new ProductTag { ProductId = id, TagId = item.Id });

            // Remove old tags
            var oldEntityTags = await _foodItemTagRepo.Queryable()
                                                      .Where(x => x.ProductId == id && (!anyTags || tags.All(tag => x.Tag.NameAr != tag && x.Tag.NameEn != tag && x.Tag.NameTr != tag)))
                                                      .ToArrayAsync();
            foreach (var item in oldEntityTags)
                _foodItemTagRepo.Delete(item);

            // Save Changes
            await _unitOfWork.SaveChangesAsync();
        }
        */
        public async Task SetTags(int id, int[] tags)
        {
            var foodItem = await _productRepo.Queryable().Include(x => x.Tags).ThenInclude(x => x.Tag).FirstOrDefaultAsync(x => x.Id == id);
            if (foodItem == null)
                return;

            var anyTags = tags.Length > 0;

            var currentTags = foodItem.Tags.Select(x => x.Tag).ToArray();
            var currentTagIds = currentTags.Select(x => x.Id).ToArray();

            //_logger.LogError("currentTagIds: [" + string.Join(",", currentTagIds) + "]");
            // Link new tags
            var newTagIds = tags.Where(x => !currentTagIds.Contains(x)).ToArray();
            //_logger.LogError("newTagIds: [" + string.Join(",", newTagIds) + "]");

            foreach (var item in newTagIds)
                _foodItemTagRepo.Insert(new ProductTag { ProductId = id, TagId = item });

            // Remove old tags
            var oldTagIds = currentTagIds.Where(x => !anyTags || !tags.Contains(x)).ToArray();
            var oldEntityTags = await _foodItemTagRepo.Queryable()
                                                      .Where(x => x.ProductId == id && oldTagIds.Contains(x.TagId))
                                                      .ToArrayAsync();
            //_logger.LogError("oldTagIds: [" + string.Join(",", oldTagIds) + "]");
            foreach (var item in oldEntityTags)
                _foodItemTagRepo.Delete(item);

            // Save Changes
            await _unitOfWork.SaveChangesAsync();
        }

    }
}
