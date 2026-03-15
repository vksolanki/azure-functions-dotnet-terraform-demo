using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;

namespace OrderProcessing.Helper
{
    public static class JwtHelper
    {
        public static string GenerateToken(string username)
        {
            // Key must be at least 32 bytes (256 bits) for HS256
            var key = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes("super-secret-test-key-1234567890-abcdef-0987654321"));

            var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

            var token = new JwtSecurityToken(
                issuer: "demo-auth",
                audience: "orders-api",
                claims: new[]
                {
                new Claim(ClaimTypes.Name, username)
                },
                expires: DateTime.UtcNow.AddMinutes(10),
                signingCredentials: creds
            );

            return new JwtSecurityTokenHandler().WriteToken(token);
        }
    }
}
