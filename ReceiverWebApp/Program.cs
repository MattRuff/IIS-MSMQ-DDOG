using Serilog;
using Serilog.Formatting.Compact;
using System.Reflection;

// Get git commit hash from assembly metadata
var gitCommitHash = Assembly.GetExecutingAssembly()
    .GetCustomAttributes<AssemblyMetadataAttribute>()
    .FirstOrDefault(a => a.Key == "GitCommitHash")?.Value ?? "unknown";

// Get application base directory for logs (works for both console and service)
var appDirectory = AppContext.BaseDirectory;
var logPath = Path.Combine(appDirectory, "logs", "receiver-.json");

// Configure Serilog with JSON formatting, file, and Windows Event Log
Log.Logger = new LoggerConfiguration()
    .Enrich.FromLogContext()
    .Enrich.WithProperty("service", "ReceiverWebApp")
    .Enrich.WithProperty("version", gitCommitHash)
    .Enrich.WithProperty("dd.service", "ReceiverWebApp")
    .Enrich.WithProperty("dd.version", gitCommitHash)
    .Enrich.WithProperty("dd.env", Environment.GetEnvironmentVariable("DD_ENV") ?? "development")
    .Enrich.With<ReceiverWebApp.DatadogExceptionEnricher>()
    .WriteTo.Console(new CompactJsonFormatter())
    .WriteTo.File(
        new CompactJsonFormatter(),
        path: logPath,
        rollingInterval: RollingInterval.Day,
        retainedFileCountLimit: 7,
        buffered: false)
    .WriteTo.EventLog(
        source: "ReceiverWebApp",
        logName: "Application",
        manageEventSource: true,
        restrictedToMinimumLevel: Serilog.Events.LogEventLevel.Information)
    .CreateLogger();

try
{
    Log.Information("Starting ReceiverWebApp with version {Version}", gitCommitHash);

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
    builder.Services.AddSingleton<ReceiverWebApp.Services.IMsmqReceiverService, ReceiverWebApp.Services.MsmqReceiverService>();

    // MOCK MODE (works on Mac/Linux/Windows without MSMQ) - for testing IIS/API only
    // Uncomment this and comment out MsmqReceiverService above to use Mock mode
    // builder.Services.AddSingleton<ReceiverWebApp.Services.IMsmqReceiverService, ReceiverWebApp.Services.MockMsmqReceiverService>();

    // Add Hosted Service for background processing
    builder.Services.AddHostedService<ReceiverWebApp.Services.MessageProcessorService>();

    var app = builder.Build();

    // Configure the HTTP request pipeline.
    app.UseSwagger();
    app.UseSwaggerUI();

    app.UseAuthorization();

    app.MapControllers();

    // Add a simple health check endpoint with version
    app.MapGet("/", () => Results.Ok(new { 
        service = "Receiver Web App",
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

