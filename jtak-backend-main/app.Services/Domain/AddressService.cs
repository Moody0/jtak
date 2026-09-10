using App.Shared.Data.App;
using App.Shared.Data.MultiContext;
using App.Shared.Entities.Domain;
using Microsoft.EntityFrameworkCore;
using Solf.Base;
using System;
using System.ComponentModel;
using System.Linq;
using System.Threading.Tasks;

namespace App.Shared.Services.Domain
{
    public interface IAddressService : ISolService<Address, AddressDto>
    {
        Task<AddressDto[]> GetUserAddresses(Guid? uid);
    }
    public class AddressService : SolService<Address, AddressDto>, IAddressService
    {
        public AddressService(ITrackableRepository<Address, AppDbContext> r)
            : base(r)
        {
        }

        public async Task<AddressDto[]> GetUserAddresses(Guid? uid)
        {
            if (!uid.HasValue)
                return Array.Empty<AddressDto>();

            return  await Queryable().Where(x => x.UserId == uid.Value)
                                     .OrderByDescending(x => x.CreatedDate)
                                     .Select(x => new AddressDto
                                     {
                                         Id = x.Id,
                                         UserId = x.UserId,
                                         Title = x.Title,

                                         FullName = x.FullName,
                                         Phonenumber = x.Phonenumber,
                                         TaxNumber = x.TaxNumber,

                                         Country = x.Country,
                                         Level1 = x.Level1,
                                         Level2 = x.Level2,
                                         Level3 = x.Level3,
                                         Level4 = x.Level4,
                                         ZipPostalCode = x.ZipPostalCode,

                                         FullAddress = x.FullAddress,
                                         Apartment = x.Apartment,

                                         Lng = x.Lng,
                                         Lat = x.Lat,

                                         IsCompany = x.IsCompany,
                                         AddressType = x.AddressType
                                     })
                                     .ToArrayAsync();
        }

        public override IQueryable<Address> OrderBy(IQueryable<Address> query, string orderColumn, ListSortDirection dir)
        {
            if (string.IsNullOrEmpty(orderColumn)) return query;
            query = orderColumn switch
            {
                //"title" => base.OrderBy(query, orderColumn.Replace("title", "Address.Title")),
                _ => base.OrderBy(query, orderColumn, dir)
            };
            return query;
        }

        public override IQueryable<Address> Search(IQueryable<Address> query, string keyword)
        {
            keyword = keyword?.Trim()?.ToLower();
            if (string.IsNullOrEmpty(keyword))
                return query;
            return query.Where(x => x.Title.ToLower().Contains(keyword));
        }
    }
}
