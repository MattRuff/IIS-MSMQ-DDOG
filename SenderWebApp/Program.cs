using Serilog;
using Serilog.Formatting.Compact;
using System.Reflection;

// Get git commit hash from assembly metadata
var gitCommitHash = Assembly.GetExecutingAssembly()
    .GetCustomAttributes<AssemblyMetadataAttribute>()
    .FirstOrDefault(a => a.Key == "GitCommitHash")?.Value ?? "unknown";

// Configure Serilog with JSON formatting and Datadog error fields
Log.Logger = new LoggerConfiguration()
    .Enrich.FromLogContext()
    .Enrich.WithProperty("service", "SenderWebApp")
    .Enrich.WithProperty("version", gitCommitHash)
    .Enrich.WithProperty("dd.service", "SenderWebApp")
    .Enrich.WithProperty("dd.version", gitCommitHash)
    .Enrich.WithProperty("dd.env", Environment.GetEnvironmentVariable("DD_ENV") ?? "development")
    .Enrich.With<SenderWebApp.DatadogExceptionEnricher>()
    .WriteTo.Console(new CompactJsonFormatter())
    .CreateLogger();

try
{
    Log.Information("Starting SenderWebApp with version {Version}", gitCommitHash);

    var builder = WebApplication.CreateBuilder(args);

    // Use Serilog for logging
    builder.Host.UseSerilog();

    // Configure for Windows Service support
    builder.Host.UseWindowsService();

    // Add services to the container.
    builder.Services.AddControllers();
    builder.Services.AddEndpointsApiExplorer();
    builder.Services.AddSwaggerGen();

    // Add MSMQ Service
    // REAL MSMQ MODE (Windows only) - Default for customer demos
    builder.Services.AddSingleton<SenderWebApp.Services.IMsmqService, SenderWebApp.Services.MsmqService>();

    // MOCK MODE (works on Mac/Linux/Windows without MSMQ) - for testing IIS/API only
    // Uncomment this and comment out MsmqService above to use Mock mode
    // builder.Services.AddSingleton<SenderWebApp.Services.IMsmqService, SenderWebApp.Services.MockMsmqService>();

    var app = builder.Build();

    // Configure the HTTP request pipeline.
    app.UseSwagger();
    app.UseSwaggerUI();

    app.UseAuthorization();

    app.MapControllers();

    // Add a simple health check endpoint with version
    app.MapGet("/", () => Results.Ok(new { 
        service = "Sender Web App",
        status = "Running",
        version = gitCommitHash,
        timestamp = DateTime.UtcNow
    }));

    app.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "Application terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush();
}

