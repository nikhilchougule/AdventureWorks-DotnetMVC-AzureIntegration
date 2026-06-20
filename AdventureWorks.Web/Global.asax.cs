using Azure.Identity;
using Azure.Security.KeyVault.Secrets;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Linq;
using System.Reflection;
using System.Web;
using System.Web.Http;
using System.Web.Mvc;
using System.Web.Optimization;
using System.Web.Routing;

namespace AdventureWorks.Web
{
    public class MvcApplication : System.Web.HttpApplication
    {
        protected void Application_Start()
        {
            // Fetch connection string from Key Vault at startup
            var keyVaultUrl = ConfigurationManager.AppSettings["KeyVaultUrl"];
            var secretName = ConfigurationManager.AppSettings["SqlSecretName"];

            var client  = new SecretClient(
                new Uri(keyVaultUrl),
                new DefaultAzureCredential()   // uses az login locally, Managed Identity in Azure
            );


            KeyVaultSecret secret = client.GetSecret(secretName);

            // Inject into ConfigurationManager at runtime
            var settings = ConfigurationManager.ConnectionStrings["AzureSqlAdventureWorks"];

            // Unlock the read-only flag via reflection
            var readOnlyField = typeof(ConfigurationElement)
                .GetField("_bReadOnly", BindingFlags.Instance | BindingFlags.NonPublic);
            readOnlyField.SetValue(settings, false);

            settings.ConnectionString = secret.Value;

            UnityConfig.RegisterComponents();
            AreaRegistration.RegisterAllAreas();
            GlobalConfiguration.Configure(WebApiConfig.Register);
            FilterConfig.RegisterGlobalFilters(GlobalFilters.Filters);
            RouteConfig.RegisterRoutes(RouteTable.Routes);
            BundleConfig.RegisterBundles(BundleTable.Bundles);
        }
    }
}
