using App.Shared.Data.MultiContext;

namespace App.Orders.Data
{
    public interface IOrdersUnitOfWork : IUnitOfWork<OrdersDbContext>
    {
        OrdersDbContext Context { get; }
    }
    public class OrdersUnitOfWork : UnitOfWork<OrdersDbContext>, IOrdersUnitOfWork
    {
        public new OrdersDbContext Context { get; }
        public OrdersUnitOfWork(OrdersDbContext context) : base(context)
        {
            Context = context;
        }
    }
}
