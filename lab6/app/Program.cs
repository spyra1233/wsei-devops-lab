using Microsoft.AspNetCore.Builder;

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/", () => "ProductAPI - Version 1.0 🟢");
// app.MapGet("/", () => "ProductAPI - Version 2.0 🔵");
app.MapGet("/health", () => new { status = "healthy", version = "1.0", timestamp = DateTime.UtcNow });
app.MapGet("/api/products", () => new[] 
{ 
    new { id = 1, name = "Laptop", price = 999.99 }, 
    new { id = 2, name = "Mouse", price = 29.99 } 
});

app.Run();
