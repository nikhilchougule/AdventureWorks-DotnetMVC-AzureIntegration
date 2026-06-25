using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Http.Filters;
using System.Web.Mvc;

namespace AdventureWorks.Web.Filters
{
    public class LogResultFilter : System.Web.Mvc.FilterAttribute, IResultFilter
    {
        public void OnResultExecuting(ResultExecutingContext filterContext)
        {
            // Runs BEFORE the result executes
        }

        public void OnResultExecuted(ResultExecutedContext filterContext)
        {
            // Runs AFTER the result executes
        }

    }
}