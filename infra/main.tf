# Automatically update APIM policy with dynamic x-functions-key after deployment
resource "null_resource" "update_apim_policy" {
  depends_on = [
    azurerm_linux_function_app.function_app
    # azurerm_api_management_api_operation_policy.submit_order_policy
  ]

  provisioner "local-exec" {
    command = "pwsh ${path.module}/update_apim_policy.ps1 -resourceGroup ${azurerm_resource_group.rg.name} -functionApp ${azurerm_linux_function_app.function_app.name} -functionName SubmitOrder -apimName ${azurerm_api_management.apim.name} -apimApiName ${azurerm_api_management_api.orders_api.name} -apimOperationId ${azurerm_api_management_api_operation.submit_order.operation_id}"
  }
}
############################################
# VARIABLES
############################################

variable "expose_function_directly" {
  description = "Allow direct public access to the Function App"
  type        = bool
  default     = true
}

############################################
# RESOURCE GROUP
############################################

resource "azurerm_resource_group" "rg" {
  name     = "vs-rg-func-demo"
  location = "Central India"
}

############################################
# APPLICATION INSIGHTS
############################################

resource "azurerm_application_insights" "insights" {
  name                = "func-demo-insights"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"

  lifecycle {
    ignore_changes = [workspace_id]
  }
}

############################################
# STORAGE ACCOUNT
############################################

resource "azurerm_storage_account" "storage" {
  name                     = "funcdemostorage1234"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "orders" {
  name                  = "orders"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
}

############################################
# SERVICE BUS
############################################

resource "azurerm_servicebus_namespace" "sb" {
  name                = "sb-order-demo-111"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
}

resource "azurerm_servicebus_queue" "orders" {
  name                 = "order-requests"
  namespace_id         = azurerm_servicebus_namespace.sb.id
  max_delivery_count   = 10
  enable_partitioning = false # or whatever your current setting is

  lifecycle {
    ignore_changes = [
      enable_partitioning,
    ]
  }
}

############################################
# APP SERVICE PLAN
############################################

resource "azurerm_service_plan" "plan" {
  name                = "func-demo-plan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "P0v3"
}

############################################
# FUNCTION APP
############################################

resource "azurerm_linux_function_app" "function_app" {
  name                = "func-demo-dotnet-app"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  service_plan_id = azurerm_service_plan.plan.id

  storage_account_name       = azurerm_storage_account.storage.name
  storage_account_access_key = azurerm_storage_account.storage.primary_access_key

  public_network_access_enabled = var.expose_function_directly

  site_config {
    application_stack {
      dotnet_version              = "8.0"
      use_dotnet_isolated_runtime = true
    }
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME    = "dotnet-isolated"
    FUNCTIONS_EXTENSION_VERSION = "~4"

    APPINSIGHTS_INSTRUMENTATIONKEY        = azurerm_application_insights.insights.instrumentation_key
    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.insights.connection_string

    ServiceBusConnection__fullyQualifiedNamespace = "${azurerm_servicebus_namespace.sb.name}.servicebus.windows.net"

    AzureWebJobsStorage__credential = "managedidentity"
  }
}

############################################
# RBAC FOR FUNCTION MANAGED IDENTITY
############################################

resource "azurerm_role_assignment" "servicebus_sender" {
  scope                = azurerm_servicebus_namespace.sb.id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = azurerm_linux_function_app.function_app.identity[0].principal_id
}

resource "azurerm_role_assignment" "servicebus_receiver" {
  scope                = azurerm_servicebus_namespace.sb.id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = azurerm_linux_function_app.function_app.identity[0].principal_id
}

resource "azurerm_role_assignment" "storage_blob_contributor" {
  scope                = azurerm_storage_account.storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_function_app.function_app.identity[0].principal_id
}

############################################
# API MANAGEMENT
############################################

resource "azurerm_api_management" "apim" {
  name                = "func-demo-apim"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  publisher_name  = "demo-publisher"
  publisher_email = "demo@example.com"

  sku_name = "Developer_1"
}

############################################
# APIM API
############################################

resource "azurerm_api_management_api" "orders_api" {
  name                = "orders-api"
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azurerm_api_management.apim.name

  revision     = "1"
  display_name = "Orders API"

  path      = "orders"
  protocols = ["https"]

  service_url = "https://${azurerm_linux_function_app.function_app.default_hostname}/api"

  depends_on = [
    azurerm_linux_function_app.function_app
  ]
}

############################################
# APIM OPERATION - LOGIN (NO JWT REQUIRED)
############################################

resource "azurerm_api_management_api_operation" "login" {
  operation_id        = "login"
  api_name            = azurerm_api_management_api.orders_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name

  display_name = "Login"

  method       = "POST"
  url_template = "/auth/login"

  description = "Authenticate user and issue JWT"

  response {
    status_code = 200
  }
}

############################################
# LOGIN POLICY (PUBLIC)
############################################

resource "azurerm_api_management_api_operation_policy" "login_policy" {
  api_name            = azurerm_api_management_api.orders_api.name
  operation_id        = azurerm_api_management_api_operation.login.operation_id
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name

  xml_content = <<XML
<policies>
  <inbound>
    <base />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
</policies>
XML
}

############################################
# APIM OPERATION FOR SubmitOrder
############################################

resource "azurerm_api_management_api_operation" "submit_order" {
  operation_id        = "submit-order"
  api_name            = azurerm_api_management_api.orders_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name

  display_name = "Submit Order"

  method       = "POST"
  url_template = "/SubmitOrder"

  description = "Submit order to service bus"

  response {
    status_code = 200
  }
}

############################################
# SUBMIT ORDER POLICY (JWT REQUIRED)
############################################

# resource "azurerm_api_management_api_operation_policy" "submit_order_policy" {
#   api_name            = azurerm_api_management_api.orders_api.name
#   operation_id        = azurerm_api_management_api_operation.submit_order.operation_id
#   api_management_name = azurerm_api_management.apim.name
#   resource_group_name = azurerm_resource_group.rg.name

#   depends_on = [
#     azurerm_api_management_api_operation.submit_order
#   ]

#     xml_content = <<XML
#   <policies>
#     <inbound>
#       <base />
#       <validate-jwt header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="Invalid or missing JWT" require-scheme="Bearer" clock-skew="300">
#         <issuer-signing-keys>
#           <key>@(Convert.ToBase64String(Encoding.UTF8.GetBytes("super-secret-test-key-1234567890-abcdef-0987654321")))</key>
#         </issuer-signing-keys>
#         <required-claims>
#           <claim name="aud" match="any">
#             <value>orders-api</value>
#           </claim>
#           <claim name="iss" match="any">
#             <value>demo-auth</value>
#           </claim>
#         </required-claims>
#       </validate-jwt>
#       <!-- TODO: Retrieve x-functions-key from function app dynamically -->
#       <set-header name="x-functions-key" exists-action="override">
#         <value>9uLXjQKq3PATyYsWsjCytP4GZxeqGBoqjnLk-UPw8fcAAzFuD1Fkbg==</value>
#       </set-header>
#     </inbound>
#     <backend>
#       <base />
#     </backend>
#     <outbound>
#       <base />
#     </outbound>
#     <on-error>
#       <base />
#     </on-error>
#   </policies>
#   XML
# }
