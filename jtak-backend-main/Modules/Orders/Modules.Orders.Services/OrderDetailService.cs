using App.Orders.Data;
using App.Shared.Data.MultiContext;
using Modules.Orders.Entities;
using Solf.Base;

namespace App.Shared.Services.eCommerce
{
    public interface IOrderDetailService : ISolService<OrderDetail, OrderDetailDto>
    {
    }
    public class OrderDetailService : SolService<OrderDetail, OrderDetailDto>, IOrderDetailService
    {
        public OrderDetailService(ITrackableRepository<OrderDetail, OrdersDbContext> repo) : base(repo)
        {
        }
    }
}
