#!/usr/bin/env pwsh
param(
    [string]$resourceGroup = "vs-rg-func-demo",
    [string]$functionApp = "func-demo-dotnet-app",
    [string]$functionName = "SubmitOrder",
    [string]$apimName = "func-demo-apim",
    [string]$apimApiName = "orders-api",
    [string]$apimOperationId = "submit-order"
)

# 1. Fetch function key
Write-Host "Fetching function key..."
$key = az functionapp function keys list --resource-group $resourceGroup --name $functionApp --function-name $functionName --query "default" -o tsv
if (-not $key) { Write-Error "Could not retrieve key."; exit 1 }

# 2. Define Policy XML
$policyXml = @"
<policies>
  <inbound>
    <base />
    <validate-jwt header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="Invalid or missing JWT" require-scheme="Bearer" clock-skew="300">
      <issuer-signing-keys>
        <key>@(Convert.ToBase64String(Encoding.UTF8.GetBytes("super-secret-test-key-1234567890-abcdef-0987654321")))</key>
      </issuer-signing-keys>
      <required-claims>
        <claim name="aud" match="any"><value>orders-api</value></claim>
        <claim name="iss" match="any"><value>demo-auth</value></claim>
      </required-claims>
    </validate-jwt>
    <set-header name="x-functions-key" exists-action="override">
      <value>$key</value>
    </set-header>
  </inbound>
  <backend><base /></backend>
  <outbound><base /></outbound>
  <on-error><base /></on-error>
</policies>
"@

# 3. Get subscription ID for REST API call
$subId = az account show --query id -o tsv

# 4. Construct the REST API URI for operation policy
$uri = "https://management.azure.com/subscriptions/$subId/resourceGroups/$resourceGroup/providers/Microsoft.ApiManagement/service/$apimName/apis/$apimApiName/operations/$apimOperationId/policies/policy?api-version=2021-08-01"

# 5. Create JSON payload
$body = @{
    properties = @{
        format = "rawxml"
        value = $policyXml
    }
} | ConvertTo-Json -Depth 10

$tempBodyFile = Join-Path $env:TEMP "apim_policy_body.json"
$body | Out-File -FilePath $tempBodyFile -Encoding utf8

# 6. Update APIM operation policy using az rest (Azure CLI REST wrapper)
Write-Host "Updating APIM operation policy..."
az rest --method PUT --uri $uri --body "@$tempBodyFile"

# 7. Cleanup
if (Test-Path $tempBodyFile) { Remove-Item $tempBodyFile }

Write-Host "APIM policy updated with dynamic x-functions-key."
