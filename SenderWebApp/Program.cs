using System;
using System.IO;
using System.Linq;
using System.Reflection;
using Microsoft.Owin.Hosting;
using Serilog;
using Serilog.Formatting.Compact;
using SenderWebApp.Services;

namespace SenderWebApp
{
    public class Program
    {
        public static void Main(string[] args)
        {
            // Get git commit hash from assembly metadata
            var gitCommitHash = Assembly.GetExecutingAssembly()
                .GetCustomAttributes(typeof(AssemblyMetadataAttribute), false)
                .Cast<AssemblyMetadataAttribute>()
                .FirstOrDefault(a => a.Key == "GitCommitHash")?.Value ?? "unknown";

            // Get application base directory for logs (works for both console and service)
            var appDirectory = AppDomain.CurrentDomain.BaseDirectory;
            var logPath = Path.Combine(appDirectory, "logs", "sender-.json");

            // Configure Serilog with JSON formatting, file, and Windows Event Log
            var loggerConfig = new LoggerConfiguration()
                .Enrich.FromLogContext()
                .Enrich.WithProperty("service", "SenderWebApp")
                .Enrich.WithProperty("version", gitCommitHash)
                .Enrich.WithProperty("dd.service", "SenderWebApp")
                .Enrich.WithProperty("dd.version", gitCommitHash)
                .Enrich.WithProperty("dd.env", Environment.GetEnvironmentVariable("DD_ENV") ?? "development")
                .Enrich.With<DatadogExceptionEnricher>()
                .WriteTo.Console(new CompactJsonFormatter())
                .WriteTo.File(
                    new CompactJsonFormatter(),
                    path: logPath,
                    rollingInterval: RollingInterval.Day,
                    retainedFileCountLimit: 7,
                    buffered: false);

            // Add Event Log sink only on Windows
            if (Environment.OSVersion.Platform == PlatformID.Win32NT)
            {
                loggerConfig.WriteTo.EventLog(
                    source: "SenderWebApp",
                    logName: "Application",
                    manageEventSource: true,
                    restrictedToMinimumLevel: Serilog.Events.LogEventLevel.Information);
            }

            Log.Logger = loggerConfig.CreateLogger();

            try
            {
                Log.Information("Starting SenderWebApp with version {Version}", gitCommitHash);

                // Initialize MSMQ Service
                IMsmqService msmqService;
                if (Environment.OSVersion.Platform == PlatformID.Win32NT)
                {
                    msmqService = new MsmqService();
                    Log.Information("Using real MSMQ service");
                }
                else
                {
                    msmqService = new MockMsmqService();
                    Log.Information("Using mock MSMQ service");
                }

                // Start OWIN web server
                string baseAddress = "http://localhost:8081/";
                
                using (WebApp.Start(baseAddress, app =>
                {
                    var startup = new OwinStartup(msmqService);
                    startup.Configuration(app);
                }))
                {
                    Log.Information("Sender Web API running on {BaseAddress}", baseAddress);
                    Console.WriteLine($"Sender Web API running on {baseAddress}");
                    Console.WriteLine("Press Enter to quit.");
                    Console.ReadLine();
                }
            }
            catch (Exception ex)
            {
                Log.Fatal(ex, "Application terminated unexpectedly");
            }
            finally
            {
                Log.CloseAndFlush();
            }
        }
    }
}
