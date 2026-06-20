using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Mvc;
using Kendo.Mvc;
using Kendo.Mvc.UI;
using AdventureWorks.Web.Repositories;
using Kendo.Mvc.Extensions;

namespace AdventureWorks.Web.Controllers
{
    public class ProductsController : Controller
    {
        public ActionResult Index()
        {
            return View();
        }

        public ActionResult GetProducts([DataSourceRequest] DataSourceRequest request)
        {
            using (var uow = new UnitOfWork())
            {
                var data = uow.Products.GetAll();

                return Json(data.ToDataSourceResult(request), JsonRequestBehavior.AllowGet);
             }
        }




    }
}