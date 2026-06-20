using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace AdventureWorks.Web.Models
{
    public class OrderLineItem
    {
        public int ProductID { get; set; }
        public string ProductName { get; set; }
        public short OrderQty { get; set; }
        public decimal UnitPrice { get; set; }
    }
}