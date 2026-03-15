using Microsoft.AspNetCore.Identity.Data;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using OrderProcessing.Helper;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

namespace OrderProcessing
{
    public class AuthLogin
    {
        private readonly ILogger<AuthLogin> _logger;

        public AuthLogin(ILogger<AuthLogin> logger)
        {
            _logger = logger;
        }

        [Function("Login")]
        public async Task<HttpResponseData> Login(
            [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "auth/login")] HttpRequestData req)
        {
            var body = await new StreamReader(req.Body).ReadToEndAsync();
            var login = JsonSerializer.Deserialize<LoginRequest>(body);

            if (login.Email != "demo@example.com" || login.Password != "password")
            {
                var unauthorized = req.CreateResponse(HttpStatusCode.Unauthorized);
                return unauthorized;
            }

            var token = JwtHelper.GenerateToken(login.Email);

            var response = req.CreateResponse(HttpStatusCode.OK);
            await response.WriteAsJsonAsync(new { access_token = token });

            return response;
        }
    }
}
