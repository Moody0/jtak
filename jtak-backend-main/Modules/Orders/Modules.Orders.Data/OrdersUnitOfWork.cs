using App.Shared.Data.MultiContext;

namespace App.Orders.Data
{
    public interface IOrdersUnitOfWork : IUnitOfWork<OrdersDbContext>
    {
    }
    public class OrdersUnitOfWork : UnitOfWork<OrdersDbContext>, IOrdersUnitOfWork
    {
        public OrdersUnitOfWork(OrdersDbContext context) : base(context)
        {
        }
    }
}
