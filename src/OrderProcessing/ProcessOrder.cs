using Azure.Messaging.ServiceBus;
using Azure.Storage.Blobs;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using System;
using System.Text.Json;
using System.Threading.Tasks;

namespace OrderProcessing;

public class ProcessOrder
{
    private readonly ILogger<ProcessOrder> _logger;

    public ProcessOrder(ILogger<ProcessOrder> logger)
    {
        _logger = logger;
    }

    //[Function(nameof(ProcessOrder))]
    //public async Task<ProcessOrderOutput> Run(
    //    [ServiceBusTrigger("order-requests", Connection = "ServiceBusConnection")]
    //     string messageBody,
    //    ServiceBusMessageActions messageActions, FunctionContext context)
    //{
    //    _logger.LogInformation("MessageBody: "+ messageBody);

    //    var order = JsonSerializer.Deserialize<Order>(messageBody);

    //    //var order = messageBody.ToObjectFromJson<Order>();
    //    // Complete the message
    //    //await messageActions.CompleteMessageAsync(message);

    //    var now = DateTime.UtcNow;
    //    _logger.LogInformation("Order Id: "+ order.OrderId);
    //    return new ProcessOrderOutput
    //    {
    //        Order = order,
    //        BlobName = order.OrderId.ToString(),

    //    };
    //}

    /// <summary>
    /// Use messageid as file name
    /// </summary>
    /// <param name="messageBody"></param>
    /// <param name="messageId"></param>
    /// <param name="messageActions"></param>
    /// <param name="context"></param>
    /// <returns></returns>
    [Function(nameof(ProcessOrder))]
    public async Task<ProcessOrderOutput> Run(
    [ServiceBusTrigger("order-requests", Connection = "ServiceBusConnection")]
          string messageBody,
        string messageId,
    ServiceBusMessageActions messageActions, FunctionContext context)
    {
        _logger.LogInformation("MessageBody: " + messageBody);
        _logger.LogInformation("messageId: " + messageId);


        var order = JsonSerializer.Deserialize<Order>(messageBody);

        //var order = messageBody.ToObjectFromJson<Order>();
        // Complete the message
        //await messageActions.CompleteMessageAsync(message);

        var now = DateTime.UtcNow;
        _logger.LogInformation("Order Id: " + order.OrderId);
        return new ProcessOrderOutput
        {
            Order = order,
            BlobName = order.OrderId.ToString(),
        };
    }

    //[Function(nameof(ProcessOrder))]
    //public async Task Run(
    //[ServiceBusTrigger("order-requests", Connection = "ServiceBusConnection")]
    //     string messageBody,
    //    string messageId,
    //ServiceBusMessageActions messageActions, FunctionContext context)
    //{
    //    _logger.LogInformation("MessageBody: " + messageBody);
    //    _logger.LogInformation("messageId: " + messageId);


    //    var order = JsonSerializer.Deserialize<Order>(messageBody);


    //    var blobServiceClient = new BlobServiceClient(
    //        Environment.GetEnvironmentVariable("AzureWebJobsStorage"));
    //    var containerClient = blobServiceClient.GetBlobContainerClient("orders");
    //    var blobClient = containerClient.GetBlobClient($"{messageId}.json");

    //    var orderJson = JsonSerializer.Serialize(order);
    //    using var stream = new MemoryStream(System.Text.Encoding.UTF8.GetBytes(orderJson));
    //    await blobClient.UploadAsync(stream, overwrite: true);
    //}

}

