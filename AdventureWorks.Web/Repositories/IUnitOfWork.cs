using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using AdventureWorks.Web.Models;

namespace AdventureWorks.Web.Repositories
{
    public interface IUnitOfWork : IDisposable
    {
        IRepository<Product> Products { get; }
        IRepository<SalesOrderHeader> Orders { get; }
        IRepository<SalesOrderDetail> OrderDetails { get; }
        int Complete();
    }
}
