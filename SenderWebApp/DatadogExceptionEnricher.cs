using Serilog.Core;
using Serilog.Events;

namespace SenderWebApp;

public class DatadogExceptionEnricher : ILogEventEnricher
{
    public void Enrich(LogEvent logEvent, ILogEventPropertyFactory propertyFactory)
    {
        if (logEvent.Exception == null)
            return;

        var exception = logEvent.Exception;

        // Add Datadog error fields
        logEvent.AddPropertyIfAbsent(propertyFactory.CreateProperty("error.message", exception.Message));
        logEvent.AddPropertyIfAbsent(propertyFactory.CreateProperty("error.type", exception.GetType().FullName ?? exception.GetType().Name));
        logEvent.AddPropertyIfAbsent(propertyFactory.CreateProperty("error.stack", exception.StackTrace ?? string.Empty));
        
        // Determine if error is handled based on log level
        // Fatal = unhandled, Error = handled (logged and caught)
        var isHandled = logEvent.Level != LogEventLevel.Fatal;
        logEvent.AddPropertyIfAbsent(propertyFactory.CreateProperty("error.handling", isHandled ? "handled" : "unhandled"));
    }
}

