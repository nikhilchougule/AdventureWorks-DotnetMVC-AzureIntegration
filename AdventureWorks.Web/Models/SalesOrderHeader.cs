using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Web;

namespace AdventureWorks.Web.Models
{
	[Table("SalesOrderHeader", Schema = "Sales")]
	public class SalesOrderHeader
	{
		[Key]
		[DatabaseGenerated(DatabaseGeneratedOption.Identity)]
		public int SalesOrderID { get; set; }

		public byte RevisionNumber { get; set; }
		public DateTime OrderDate { get; set; }
		public DateTime DueDate { get; set; }
		public DateTime? ShipDate { get; set; }
		public byte Status { get; set; }
		public bool OnlineOrderFlag { get; set; }

		[DatabaseGenerated(DatabaseGeneratedOption.Computed)]
		public string SalesOrderNumber { get; set; }

		public int CustomerID { get; set; }
		public int? TerritoryID { get; set; }
		public int BillToAddressID { get; set; }
		public int ShipToAddressID { get; set; }
		public int ShipMethodID { get; set; }

		public decimal SubTotal { get; set; }
		public decimal TaxAmt { get; set; }
		public decimal Freight { get; set; }

		[DatabaseGenerated(DatabaseGeneratedOption.Computed)]
		public decimal TotalDue { get; set; }

		public string Comment { get; set; }
		public Guid rowguid { get; set; }
		public DateTime ModifiedDate { get; set; }

		// Navigation property — EF6 populates line items in same SaveChanges
		public virtual ICollection<SalesOrderDetail> SalesOrderDetails { get; set; }

		public SalesOrderHeader()
		{
			SalesOrderDetails = new List<SalesOrderDetail>();
		}
	}
}