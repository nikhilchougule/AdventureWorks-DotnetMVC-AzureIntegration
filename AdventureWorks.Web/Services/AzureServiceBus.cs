using Azure.Identity;
using Azure.Security.KeyVault.Secrets;
using Newtonsoft.Json;
using Azure.Messaging.ServiceBus;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Linq;
using System.Threading.Tasks;
using System.Web;

namespace AdventureWorks.Web.Services
{
    public class AzureServiceBus
    {
        private static string _cachedConnectionString;

        private string GetConnectionString()
        {
            if (_cachedConnectionString != null)
                return _cachedConnectionString;

            var kvUrl = ConfigurationManager.AppSettings["KeyVaultUrl"];
            var secretName = ConfigurationManager.AppSettings["ServiceBusSecretName"];

            var client = new SecretClient(new Uri(kvUrl), new DefaultAzureCredential());
            _cachedConnectionString = client.GetSecret(secretName).Value.Value;
            return _cachedConnectionString;
        }

        public async Task SendNewOrderMessageAsync(int salesOrderId, string customerName, decimal totalDue)
        {
            var queueName = ConfigurationManager.AppSettings["NewOrdersQueue"];
            var connStr = GetConnectionString();

            var client = new ServiceBusClient(connStr);
            try
            {
                var sender = client.CreateSender(queueName);

                var payload = JsonConvert.SerializeObject(new
                {
                    SalesOrderID = salesOrderId,
                    CustomerName = customerName,
                    TotalDue = totalDue,
                    PlacedAt = DateTime.UtcNow
                });

                var message = new ServiceBusMessage(payload)
                {
                    Subject = $"NewOrder-{salesOrderId}",
                    ContentType = "application/json",
                    MessageId = Guid.NewGuid().ToString()
                };

                await sender.SendMessageAsync(message);
            }
            finally
            {
                await client.DisposeAsync();
            }
        }

    }
}