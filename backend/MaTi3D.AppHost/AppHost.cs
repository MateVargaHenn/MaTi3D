#pragma warning disable ASPIREJAVASCRIPT001

var builder = DistributedApplication.CreateBuilder(args);

var database = builder.AddConnectionString("mati3d");

var api = builder.AddProject<Projects.MaTi3D_WebApi>("api")
    .WithReference(database);

builder.AddJavaScriptApp(
        "web",
        "../../frontend",
        runScriptName: "start")
    .WithHttpEndpoint(
        port: 4200,
        targetPort: 4200,
        isProxied: false)
    .WithReference(api)
    .WaitFor(api);

builder.Build().Run();