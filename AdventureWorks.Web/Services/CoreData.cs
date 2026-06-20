using AdventureWorks.Web.Models;
using AdventureWorks.Web.Repositories;
using Microsoft.Data.SqlClient;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Linq;
using System.Web;

namespace AdventureWorks.Web.Services
{
    public class CoreData
    {
        private readonly IUnitOfWork _unitOfWork;

        public CoreData(IUnitOfWork unitOfWork)
        {
            _unitOfWork = unitOfWork;
        }

        private string ConnectionString => ConfigurationManager.ConnectionStrings["AzureSqlAdventureWorks"].ConnectionString;

        public int CreateOrder(int customerId, DateTime dueDate,
                            List<OrderLineItem> lineItems,
                            out string customerName, out decimal totalDue)
        {
            // Resolve customer name via LINQ
            customerName = _unitOfWork.Orders
                .GetAll()
                .Where(o => o.CustomerID == customerId)
                .Select(o => o.SalesOrderNumber)
                .FirstOrDefault() ?? "N/A";

            // For customer name we still need a JOIN — use a small ADO.NET call
            customerName = GetCustomerName(customerId);

            // Compute totals from line items using LINQ
            decimal subTotal = lineItems.Sum(i => i.UnitPrice * i.OrderQty);
            decimal taxAmt = Math.Round(subTotal * 0.08m, 2);
            decimal freight = Math.Round(subTotal * 0.02m, 2);
            totalDue = subTotal + taxAmt + freight;

            // Build the order header entity
            var order = new SalesOrderHeader
            {
                RevisionNumber = 1,
                OrderDate = DateTime.Now,
                DueDate = dueDate,
                Status = 1,       // In Process
                OnlineOrderFlag = false,
                CustomerID = customerId,
                TerritoryID = 1,
                BillToAddressID = 985,
                ShipToAddressID = 985,
                ShipMethodID = 5,
                SubTotal = subTotal,
                TaxAmt = taxAmt,
                Freight = freight,
                rowguid = Guid.NewGuid(),
                ModifiedDate = DateTime.Now
            };

            // Build line item entities using LINQ Select
            order.SalesOrderDetails = lineItems.Select(item => new SalesOrderDetail
            {
                OrderQty = item.OrderQty,
                ProductID = item.ProductID,
                SpecialOfferID = 1,
                UnitPrice = item.UnitPrice,
                UnitPriceDiscount = 0,
                rowguid = Guid.NewGuid(),
                ModifiedDate = DateTime.Now
            }).ToList();

            // Persist — EF6 inserts header + all detail rows in one transaction
            _unitOfWork.Orders.Add(order);
            _unitOfWork.Complete();

            return order.SalesOrderID;  // EF6 populates identity after Complete()
        }

        // ── All existing read methods below (unchanged) ─────────────────
        //public IEnumerable<Dictionary<string, object>> GetOrders(int top = 50) { /* existing */ }
        //public IEnumerable<Dictionary<string, object>> GetCustomers(string term = null) { /* existing */ }
        //public IEnumerable<Dictionary<string, object>> GetTerritories() { /* existing */ }
        //public IEnumerable<Dictionary<string, object>> GetOrdersByMonth() { /* existing */ }
        //public IEnumerable<Dictionary<string, object>> GetCustomersForDropdown() { /* existing */ }
        //public IEnumerable<Dictionary<string, object>> GetProductsForDropdown() { /* existing */ }
        // Small helper — customer name requires Person JOIN, keep as ADO.NET

        public IEnumerable<Dictionary<string, object>> GetCustomersForDropdown()
        {
            var results = new List<Dictionary<string, object>>();
            using (var conn = new SqlConnection(ConnectionString))
            using (var cmd = new SqlCommand(@"
        SELECT TOP 200
            c.CustomerID,
            ISNULL(p.FirstName + ' ' + p.LastName, 'Store-' + CAST(c.CustomerID AS VARCHAR)) AS FullName
        FROM Sales.Customer c
        LEFT JOIN Person.Person p ON c.PersonID = p.BusinessEntityID
        ORDER BY FullName", conn))
            {
                conn.Open();
                using (var reader = cmd.ExecuteReader())
                {
                    while (reader.Read())
                        results.Add(new Dictionary<string, object>
                        {
                            ["CustomerID"] = reader.GetInt32(0),
                            ["FullName"] = reader.GetString(1)
                        });
                }
            }
            return results;
        }

        public IEnumerable<Dictionary<string, object>> GetProductsForDropdown()
        {
            var results = new List<Dictionary<string, object>>();
            using (var conn = new SqlConnection(ConnectionString))
            using (var cmd = new SqlCommand(@"
        SELECT ProductID, Name, ListPrice
        FROM Production.Product
        WHERE FinishedGoodsFlag = 1 AND DiscontinuedDate IS NULL
        ORDER BY Name", conn))
            {
                conn.Open();
                using (var reader = cmd.ExecuteReader())
                {
                    while (reader.Read())
                        results.Add(new Dictionary<string, object>
                        {
                            ["ProductID"] = reader.GetInt32(0),
                            ["Name"] = reader.GetString(1),
                            ["ListPrice"] = reader.GetDecimal(2)
                        });
                }
            }
            return results;
        }

        private string GetCustomerName(int customerId)
        {
            using (var conn = new SqlConnection(ConnectionString))
            using (var cmd = new SqlCommand(@"
                SELECT ISNULL(p.FirstName + ' ' + p.LastName, 'N/A')
                FROM Sales.Customer c
                LEFT JOIN Person.Person p ON c.PersonID = p.BusinessEntityID
                WHERE c.CustomerID = @id", conn))
            {
                cmd.Parameters.AddWithValue("@id", customerId);
                conn.Open();
                return cmd.ExecuteScalar()?.ToString() ?? "N/A";
            }
        }

    }
}