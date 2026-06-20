using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Web;

namespace AdventureWorks.Web.Models
{
    [Table("SalesOrderDetail", Schema = "Sales")]
    public class SalesOrderDetail
    {
        [Key, Column(Order = 0)]
        public int SalesOrderID { get; set; }

        [Key, Column(Order = 1)]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int SalesOrderDetailID { get; set; }

        public short OrderQty { get; set; }
        public int ProductID { get; set; }
        public int SpecialOfferID { get; set; }
        public decimal UnitPrice { get; set; }
        public decimal UnitPriceDiscount { get; set; }

        [DatabaseGenerated(DatabaseGeneratedOption.Computed)]
        public decimal LineTotal { get; set; }

        public Guid rowguid { get; set; }
        public DateTime ModifiedDate { get; set; }

        [ForeignKey("SalesOrderID")]
        public virtual SalesOrderHeader SalesOrderHeader { get; set; }
    }
}