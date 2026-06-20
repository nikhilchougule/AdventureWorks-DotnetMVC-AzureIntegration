
using AdventureWorks.Web.Models;
using AdventureWorks.Web.Services;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Web;
using System.Web.Mvc;

namespace AdventureWorks.Web.Controllers
{
    public class OrdersController : Controller
    {
        private readonly CoreData _service;
        private readonly AzureServiceBus _serviceBus;

        // Unity resolves and injects both dependencies automatically
        public OrdersController(CoreData service,
                                AzureServiceBus serviceBus)
        {
            _service = service;
            _serviceBus = serviceBus;
        }

        //public ActionResult Index()
        //{
        //    ViewBag.Territories = _service.GetTerritories();
        //    return View();
        //}

        //public ActionResult GetOrders(int top = 50)
        //{
        //    return Json(_service.GetOrders(top), JsonRequestBehavior.AllowGet);
        //}

        //public ActionResult SearchCustomers(string term)
        //{
        //    return Json(_service.GetCustomers(term), JsonRequestBehavior.AllowGet);
        //}

        [HttpGet]
        public ActionResult Create()
        {
            ViewBag.Customers = _service.GetCustomersForDropdown();
            ViewBag.Products = _service.GetProductsForDropdown();
            return View();
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<ActionResult> Create(int customerId, string dueDate,
                                               string lineItemsJson)
        {
            if (!DateTime.TryParseExact(dueDate, "yyyy-MM-dd", System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.None, out DateTime parsedDueDate))
            {
                ModelState.AddModelError("", "Invalid due date.");
                ViewBag.Customers = _service.GetCustomersForDropdown();
                ViewBag.Products = _service.GetProductsForDropdown();
                return View();
            }

            if (string.IsNullOrWhiteSpace(lineItemsJson))
            {
                ModelState.AddModelError("", "At least one line item is required.");
                ViewBag.Customers = _service.GetCustomersForDropdown();
                ViewBag.Products = _service.GetProductsForDropdown();
                return View();
            }

            var lineItems = JsonConvert.DeserializeObject<List<OrderLineItem>>(lineItemsJson);

            string customerName;
            decimal totalDue;
            int newOrderId = _service.CreateOrder(customerId, parsedDueDate, lineItems,
                                                  out customerName, out totalDue);

            await _serviceBus.SendNewOrderMessageAsync(newOrderId, customerName, totalDue);

            TempData["Success"] = $"Order #{newOrderId} placed for {customerName}. Total: {totalDue:C2}";

            return RedirectToAction("Create");
        }
    }

}