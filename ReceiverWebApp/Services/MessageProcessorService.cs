using System;
using System.Threading;
using System.Threading.Tasks;
using Datadog.Trace;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using ReceiverWebApp.Models;

namespace ReceiverWebApp.Services
{
    public class MessageProcessorService : BackgroundService
    {
        private readonly IMsmqReceiverService _msmqReceiverService;
        private readonly ILogger<MessageProcessorService> _logger;
        private readonly IConfiguration _configuration;

        public MessageProcessorService(
            IMsmqReceiverService msmqReceiverService,
            ILogger<MessageProcessorService> logger,
            IConfiguration configuration)
        {
            _msmqReceiverService = msmqReceiverService;
            _logger = logger;
            _configuration = configuration;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("Message Processor Service starting...");

            try
            {
                // Start the receiver (event-driven for real MSMQ, no-op for mock)
                _msmqReceiverService.Start();
                _logger.LogInformation("MSMQ receiver started");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to start MSMQ receiver - service cannot function");
                return;
            }

            _logger.LogInformation("Message Processor Service ready, monitoring in-memory queue...");

            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    // Pull from in-memory queue (filled by MSMQ events)
                    var message = _msmqReceiverService.ReceiveMessage();

                    if (message != null)
                    {
                        await ProcessOrder(message);
                    }
                    else
                    {
                        // No messages in buffer, check again soon
                        await Task.Delay(TimeSpan.FromMilliseconds(500), stoppingToken);
                    }
                }
                catch (OperationCanceledException)
                {
                    // Service is stopping - this is normal, don't log as error
                    break;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error in message processing loop");
                    
                    try
                    {
                        // Delay after errors to allow recovery
                        await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
                    }
                    catch (OperationCanceledException)
                    {
                        // Service stopping during error delay
                        break;
                    }
                }
            }

            _logger.LogInformation("Message Processor Service stopped");
        }

        private async Task ProcessOrder(OrderMessage order)
        {
            // Create a Datadog span for message processing
            using (var scope = Tracer.Instance.StartActive("msmq.process"))
            {
                var span = scope.Span;
                span.Type = "queue"; // Use string instead of SpanTypes constant for .NET Framework compatibility
                span.ResourceName = "process.order";
                span.SetTag("order.id", order.OrderId);
                span.SetTag("order.customer", order.CustomerName);
                span.SetTag("order.product", order.ProductName);
                span.SetTag("messaging.system", "msmq");
                span.SetTag("messaging.operation", "process");
                
                try
                {
                    _logger.LogInformation($"Processing order: {order.OrderId}");
                    _logger.LogInformation($"Customer: {order.CustomerName}, Product: {order.ProductName}, Quantity: {order.Quantity}, Amount: ${order.TotalAmount}");

                    // Simulate some processing work
                    await Task.Delay(TimeSpan.FromSeconds(1));

                    // Update order status
                    order.Status = "Processed";

                    _logger.LogInformation($"Order {order.OrderId} processed successfully");
                    
                    span.SetTag("order.status", "processed");
                }
                catch (Exception ex)
                {
                    span.SetException(ex);
                    span.SetTag("order.status", "failed");
                    _logger.LogError(ex, $"Error processing order {order.OrderId}");
                    order.Status = "Failed";
                    throw;
                }
            }
        }
    }
}

