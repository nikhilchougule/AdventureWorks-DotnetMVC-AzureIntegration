using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Web;

namespace AdventureWorks.Web.Models
{
    [Table("Product",Schema="Production")]
    public class Product
    {
        [Key]
        public int ProductID { get; set; }
        public string Name { get; set; }
        public string ProductNumber { get; set; }
        public string Color { get; set; }
        public decimal StandardCost { get; set; }
        public decimal ListPrice { get; set; }
        public string Size { get; set; }
        public decimal? Weight { get; set; }
        public string ProductLine { get; set; }
        public string Class { get; set; }
        public DateTime SellStartDate { get; set; }
        public DateTime? DiscontinuedDate { get; set; }
    }
}