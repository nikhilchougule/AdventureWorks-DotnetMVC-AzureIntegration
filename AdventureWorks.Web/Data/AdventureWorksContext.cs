using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Data.Entity;
using AdventureWorks.Web.Models;

namespace AdventureWorks.Web.Data
{
    public class AdventureWorksContext : DbContext
    {
        static AdventureWorksContext()
        {
            Database.SetInitializer<AdventureWorksContext>(null);
        }

        public AdventureWorksContext() : base("name=AzureSqlAdventureWorks")
        {
            this.Database.CommandTimeout = 500; // seconds
        }

        public DbSet<Product> Products { get; set; }
        public DbSet<SalesOrderHeader> SalesOrderHeaders { get; set; }
        public DbSet<SalesOrderDetail> SalesOrderDetails { get; set; }

    }
}