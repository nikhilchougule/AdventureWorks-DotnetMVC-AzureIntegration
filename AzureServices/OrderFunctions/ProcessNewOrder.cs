using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace AzureServices.OrderFunctions;

public class ProcessNewOrder
{
    private readonly ILogger<ProcessNewOrder> _logger;

    public ProcessNewOrder(ILogger<ProcessNewOrder> logger)
    {
        _logger = logger;
    }

    [Function("ProcessNewOrder")]
    public void Run(
        [ServiceBusTrigger("%NewOrdersQueue%", Connection = "ServiceBusConnection")] string messageBody,
        FunctionContext context)
    {
        _logger.LogInformation("New order received: {Body}", messageBody);

        // TODO: deserialize messageBody (JSON) and process the order
    }
}