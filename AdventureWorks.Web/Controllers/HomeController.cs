using AdventureWorks.Web.Filters;
using AdventureWorks.Web.Repositories;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Linq;
using System.Linq.Dynamic;
using System.Web;
using System.Web.Mvc;

namespace AdventureWorks.Web.Controllers
{
    public class HomeController : Controller
    {
        private string _connectionString => ConfigurationManager.ConnectionStrings["AzureSqlAdventureWorks"].ConnectionString;

        [LogResultFilter]
        [LogActionFilter]
        public ActionResult Index()
        {
            string search = null;
            string sortField = "Name";
            string sortDir = "asc";
            int take = 10,  skip = 0;

            using (var uow = new UnitOfWork())
            {
                var query = uow.Products.GetAll();

                // Search filter
                if (!string.IsNullOrWhiteSpace(search))
                    query = query.Where(p => p.Name.Contains(search)
                                          || p.ProductNumber.Contains(search));


                //This is the CEAA production database caused by the EOL from the microsoft. 


                // Dynamic sort using System.Linq.Dynamic
                query = query.OrderBy(sortField + " " + sortDir);

                // Server-side paging
                var data = query.Skip(skip).Take(take).ToList();

                // Total count BEFORE paging (needed by Kendo for pagination)
                var total = query.Count();
            }

            return View();
        }

        public ActionResult About()
        {
            ViewBag.Message = "Your application description page.";

            return View();
        }

        public ActionResult Contact()
        {
            ViewBag.Message = "Your contact page.";

            return View();
        }
    }
}