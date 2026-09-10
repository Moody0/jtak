using App.Shared.Entities.Domain;
using Microsoft.EntityFrameworkCore;
using Solf.Base;
using System.ComponentModel;
using System.Linq;
using System.Threading.Tasks;
using URF.Core.Abstractions.Trackable;

namespace App.Shared.Services.Domain
{
    public interface ITestimonialService : ISolService<Testimonial, TestimonialTranslation, TestimonialDto>
    {
        Task<Testimonial> FindAsync(int? id);
    }
    public class TestimonialService : SolService<Testimonial, TestimonialTranslation, TestimonialDto>, ITestimonialService
    {
        public TestimonialService(ITrackableRepository<Testimonial> r, ITrackableRepository<TestimonialTranslation> tr)
            : base(r, tr)
        {
        }

        public async Task<Testimonial> FindAsync(int? id) =>
            await Queryable().Include(x => x.Translations).FirstOrDefaultAsync(x => x.Id == id);


        public override IQueryable<Testimonial> OrderBy(IQueryable<Testimonial> query, string orderColumn, ListSortDirection dir)
        {
            if (string.IsNullOrEmpty(orderColumn)) return query;
            query = orderColumn switch
            {
                //"title" => base.OrderBy(query, orderColumn.Replace("title", "Testimonial.Title")),
                _ => base.OrderBy(query, orderColumn, dir)
            };
            return query;
        }

        public override IQueryable<Testimonial> Search(IQueryable<Testimonial> query, string keyword)
        {
            keyword = keyword?.Trim()?.ToLower();
            if (string.IsNullOrEmpty(keyword))
                return query;
            return query.Where(x => x.Translations.Any(t => t.Name.ToLower().Contains(keyword) || t.Text.ToLower().Contains(keyword)));
        }
    }
}
