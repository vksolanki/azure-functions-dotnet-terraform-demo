using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;

public record Order(string OrderId, string CustomerId, decimal Amount);

public class SubmitOrderOutput
{
    [ServiceBusOutput("order-requests", Connection = "ServiceBusConnection")]
    public Order Message { get; set; }

    public HttpResponseData HttpResponse { get; set; }
}

public class ProcessOrderOutput
{
    [BlobOutput("orders/{messageId}.json", Connection = "AzureWebJobsStorage")]
    public Order Order { get; set; }

    public string BlobName { get; set; }
}