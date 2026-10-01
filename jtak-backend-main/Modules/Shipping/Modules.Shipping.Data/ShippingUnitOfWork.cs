using App.Shared.Data.MultiContext;

namespace App.Shipping.Data
{
    public interface IShippingUnitOfWork : IUnitOfWork<ShippingDbContext>
    {
        ShippingDbContext Context { get; }
    }
    public class ShippingUnitOfWork : UnitOfWork<ShippingDbContext>, IShippingUnitOfWork
    {
        public ShippingUnitOfWork(ShippingDbContext context) : base(context)
        {
        }

        public new ShippingDbContext Context => (ShippingDbContext)base.Context;
    }
}
