using App.Shared.Data.MultiContext;

namespace App.Shipping.Data
{
    public interface IShippingUnitOfWork : IUnitOfWork<ShippingDbContext>
    {
    }
    public class ShippingUnitOfWork : UnitOfWork<ShippingDbContext>, IShippingUnitOfWork
    {
        public ShippingUnitOfWork(ShippingDbContext context) : base(context)
        {
        }
    }
}
