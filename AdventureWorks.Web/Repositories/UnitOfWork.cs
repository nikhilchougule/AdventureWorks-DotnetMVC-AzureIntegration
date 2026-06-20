using AdventureWorks.Web.Data;
using AdventureWorks.Web.Models;

namespace AdventureWorks.Web.Repositories
{
    public class UnitOfWork : IUnitOfWork
    {
        private readonly AdventureWorksContext _context;

        public int Complete() => _context.SaveChanges();

        public void Dispose() => _context.Dispose();

        public UnitOfWork()
        {
            _context = new AdventureWorksContext();
            Products = new Repository<Product>(_context);
            Orders = new Repository<SalesOrderHeader>(_context);
            OrderDetails = new Repository<SalesOrderDetail>(_context);
        }

        public IRepository<Product> Products { get; private set; }
        public IRepository<SalesOrderHeader> Orders { get; private set; }
        public IRepository<SalesOrderDetail> OrderDetails { get; private set; }
    }
}