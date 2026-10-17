using System.Net;
using Microsoft.AspNetCore.HttpOverrides;

var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();

builder.Services.AddControllers();
builder.Services.AddOpenApi();

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders =
        ForwardedHeaders.XForwardedFor |
        ForwardedHeaders.XForwardedProto;

    if (IPAddress.TryParse(
        builder.Configuration["ReverseProxy:KnownProxy"],
        out var proxy))
    {
        options.KnownProxies.Add(proxy);
    }
});

var app = builder.Build();

app.UseForwardedHeaders();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.UseHttpsRedirection();
}

app.UseAuthorization();

app.MapControllers();
app.MapDefaultEndpoints();
app.MapHealthChecks("/api/health");

app.Run();