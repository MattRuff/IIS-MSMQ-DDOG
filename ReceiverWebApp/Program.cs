using System;
using System.IO;
using System.Linq;
using System.Reflection;
using Microsoft.Owin.Hosting;
using Serilog;
using Serilog.Formatting.Compact;
using ReceiverWebApp.Services;

namespace ReceiverWebApp
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
            var logPath = Path.Combine(appDirectory, "logs", "receiver-.json");

            // Configure Serilog with JSON formatting, file, and Windows Event Log
            var loggerConfig = new LoggerConfiguration()
                .Enrich.FromLogContext()
                .Enrich.WithProperty("service", "ReceiverWebApp")
                .Enrich.WithProperty("version", gitCommitHash)
                .Enrich.WithProperty("dd.service", "ReceiverWebApp")
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
                    source: "ReceiverWebApp",
                    logName: "Application",
                    manageEventSource: true,
                    restrictedToMinimumLevel: Serilog.Events.LogEventLevel.Information);
            }

            Log.Logger = loggerConfig.CreateLogger();

            MessageProcessorService messageProcessor = null;

            try
            {
                Log.Information("Starting ReceiverWebApp with version {Version}", gitCommitHash);

                // Initialize MSMQ Receiver Service
                IMsmqReceiverService msmqReceiverService;
                if (Environment.OSVersion.Platform == PlatformID.Win32NT)
                {
                    msmqReceiverService = new MsmqReceiverService();
                    Log.Information("Using real MSMQ receiver service");
                }
                else
                {
                    msmqReceiverService = new MockMsmqReceiverService();
                    Log.Information("Using mock MSMQ receiver service");
                }

                // Start message processor in background
                messageProcessor = new MessageProcessorService(msmqReceiverService);
                messageProcessor.Start();

                // Start OWIN web server
                string baseAddress = "http://localhost:8082/";
                
                using (WebApp.Start(baseAddress, app =>
                {
                    var startup = new OwinStartup(msmqReceiverService);
                    startup.Configuration(app);
                }))
                {
                    Log.Information("Receiver Web API running on {BaseAddress}", baseAddress);
                    Console.WriteLine($"Receiver Web API running on {baseAddress}");
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
                messageProcessor?.Stop();
                messageProcessor?.Dispose();
                Log.CloseAndFlush();
            }
        }
    }
}
