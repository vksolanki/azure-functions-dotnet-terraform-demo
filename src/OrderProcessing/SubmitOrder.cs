using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using System.Net;

namespace OrderProcessing;

public class SubmitOrder
{
    private readonly ILogger<SubmitOrder> _logger;

    public SubmitOrder(ILogger<SubmitOrder> logger)
    {
        _logger = logger;
    }


    [Function("SubmitOrder")]
    public async Task<SubmitOrderOutput> Run(
        [HttpTrigger(AuthorizationLevel.Function, "post")] HttpRequestData req,
        FunctionContext executionContext)
    {
        var logger = executionContext.GetLogger("SubmitOrder");

        // 1. Parse JSON to Object
        var order = await req.ReadFromJsonAsync<Order>();

        // 2. Validation Logic
        if (order == null || order.Amount <= 0)
        {
            logger.LogWarning("Validation failed: Amount is 0 or less.");
            return new SubmitOrderOutput
            {
                HttpResponse = req.CreateResponse(HttpStatusCode.BadRequest)
            };
        }

        // 3. Success: Set the Message and the OK Response
        var response = req.CreateResponse(HttpStatusCode.OK);
        await response.WriteStringAsync($"Order {order.OrderId} accepted.");

        return new SubmitOrderOutput
        {
            Message = order, // This triggers the Service Bus output
            HttpResponse = response
        };
    }
}
