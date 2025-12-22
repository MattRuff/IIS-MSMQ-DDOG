using System;
using System.IO;
using System.Linq;
using System.Reflection;
using Microsoft.AspNetCore;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Hosting;
using Serilog;
using Serilog.Formatting.Compact;

namespace SenderWebApp
{
    public class Program
    {
        public static void Main(string[] args)
        {
            // Get git commit hash from assembly metadata
            var gitCommitHash = Assembly.GetExecutingAssembly()
                .GetCustomAttributes<AssemblyMetadataAttribute>()
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
                CreateWebHostBuilder(args).Build().Run();
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

        public static IWebHostBuilder CreateWebHostBuilder(string[] args) =>
            WebHost.CreateDefaultBuilder(args)
                .UseUrls("http://localhost:8081")
                .UseSerilog()
                .UseStartup<Startup>()
                .UseWindowsService(); // Enable Windows Service support
    }
}
