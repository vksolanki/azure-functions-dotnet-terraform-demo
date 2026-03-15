# Azure Functions Local Development Quick Reference

## 1. Start Azurite (Storage Emulator)
```
npx azurite --skipApiVersionCheck
```

## 2. Create a New Azure Functions Project (Isolated Worker, .NET 8)
```
func init OrderProcessing --worker-runtime dotnetIsolated --target-framework net8.0
cd OrderProcessing
```

## 3. Add Functions
- **HTTP Trigger:**
  ```
  func new --template "HttpTrigger" --name SubmitOrder
  ```
- **Queue Trigger:**
  ```
  func new --template "QueueTrigger" --name ProcessOrder
  func new --template "ServiceBusQueueTrigger" --name ProcessOrder
  ```

## 4. Run Functions Locally
```
func start
```

## 5. Send Message to Queue (Azurite)
- **Create queue:**
  ```
  az storage queue create --name myqueue-items --connection-string "UseDevelopmentStorage=true"
  ```
- **Send plain message:**
  ```
  az storage message put --queue-name myqueue-items --content "Hello from local!" --connection-string "UseDevelopmentStorage=true"
  ```
- **Send base64 message:**
  ```
  az storage message put --queue-name myqueue-items --content "SGVsbG8gZnJvbSBsb2NhbCE=" --base64 --connection-string "UseDevelopmentStorage=true"
  ```

## 6. Publish, Zip, and Deploy to Azure
- **Publish:**
  ```
  dotnet publish -c Release -o ./publish
  ```
- **Zip:**
  ```
  cd publish
  Compress-Archive -Path ./publish/* -DestinationPath ./publish.zip -Force
  cd ..
  ```
- **Deploy:**
  ```
  az functionapp deployment source config-zip --resource-group <resource-group> --name <function-app-name> --src ./publish.zip

  az functionapp deployment source config-zip --resource-group vs-rg-func-demo --name func-demo-dotnet-app --src ./publish.zip --debug
  ```

## 7. How APIM and Function App Trigger Flow Works

### Overview
Azure API Management (APIM) acts as a gateway between clients and your Azure Function App. It provides security, rate limiting, transformation, and monitoring for your APIs.

### Flow Steps
1. **Client Request:**
   - The client sends an HTTP request to the APIM endpoint (e.g., https://<apim-name>.azure-api.net/orders/SubmitOrder).
2. **APIM Inbound Processing:**
   - APIM applies inbound policies (e.g., JWT validation, header injection, logging).
   - If a JWT is required, APIM validates the token and extracts claims.
   - APIM injects the `x-functions-key` header if required for the backend function.
3. **Forward to Function App:**
   - APIM forwards the request to the Azure Function App's HTTP trigger endpoint (e.g., https://<function-app>.azurewebsites.net/api/SubmitOrder).
   - The function app receives the request, processes authentication/authorization if needed, and executes the function logic.
4. **Function App Response:**
   - The function app returns a response to APIM.
5. **APIM Outbound Processing:**
   - APIM applies outbound policies (e.g., response transformation, logging).
6. **Client Receives Response:**
   - The client receives the final response from APIM.

### Diagram
```
Client → APIM (policies, security) → Function App (trigger) → APIM (outbound) → Client
```

### Key Points
- APIM can secure, transform, and monitor all traffic to your function app.
- APIM policies (like JWT validation and header injection) run before the function is triggered.
- The function app only needs to expose HTTP triggers; APIM handles the rest.

## 8. Test Function API with APIM (Replace token from login response)

```bash
curl --location 'https://func-demo-apim.azure-api.net/orders/auth/login' \
--header 'Ocp-Apim-Subscription-Key: keyyyyy' \
--header 'Content-Type: application/json' \
--data-raw '{
  "Email": "demo@example.com",
  "Password": "password"
}'


curl --location 'https://func-demo-apim.azure-api.net/orders/SubmitOrder' \
--header 'Ocp-Apim-Subscription-Key: keyyyyy' \
--header 'Authorization: Bearer <replace-token-from-response>' \
--header 'Content-Type: application/json' \
--data '{
  "OrderId": "61",
  "CustomerId": "CUST-002",
  "Amount":  522
}'

## 8. OrderProcessing Function App Trigger Flow

### HTTP Trigger (e.g., SubmitOrder)
1. **Client/API Gateway (APIM) sends HTTP POST to /api/SubmitOrder**
2. **Azure Function App (OrderProcessing) receives HTTP request**
   - The HTTP-triggered function (SubmitOrder) is invoked.
   - Function code processes the request (e.g., validates input, creates order, enqueues message).
3. **Function returns HTTP response**
   - Response is sent back to APIM (if used) or directly to the client.

### Queue Trigger (e.g., ProcessOrder)
1. **Message is placed in Azure Storage Queue or Service Bus Queue**
   - This can be done by the SubmitOrder function or any other producer.
2. **Azure Function App (OrderProcessing) monitors the queue**
   - The queue-triggered function (ProcessOrder) is automatically invoked when a new message arrives.
   - Function code processes the message (e.g., updates order status, sends notifications).
3. **Function completes processing**
   - Message is removed from the queue if processed successfully.

### Example Flow
```
Client → APIM → HTTP Trigger (SubmitOrder) → Queue (order-requests) → Queue Trigger (ProcessOrder)
```

### Key Points
- HTTP triggers are entry points for API calls (e.g., order submission).
- Queue triggers handle background processing and decouple workloads.
- Both triggers are defined in the OrderProcessing Function App and can work together for robust workflows.

#### Queue Trigger (ProcessOrder) with Blob Storage Output
1. **Message is placed in Azure Storage Queue or Service Bus Queue**
   - This can be done by the SubmitOrder function or any other producer.
2. **Azure Function App (OrderProcessing) monitors the queue**
   - The queue-triggered function (ProcessOrder) is automatically invoked when a new message arrives.
   - Function code processes the message (e.g., updates order status, sends notifications).
3. **Function writes output to Blob Storage**
   - The function can serialize the processed message or result as JSON and write it to Azure Blob Storage (e.g., for archiving, auditing, or further processing).
4. **Function completes processing**
   - Message is removed from the queue if processed successfully.

##### Example Flow with Blob Output
```
Client → APIM → HTTP Trigger (SubmitOrder) → Queue (order-requests) → Queue Trigger (ProcessOrder) → Blob Storage (write JSON)
```

##### Key Points
- Queue triggers can output to Blob Storage by binding an output parameter or using the Azure SDK.
- This pattern is useful for archiving, analytics, or chaining further processing steps.