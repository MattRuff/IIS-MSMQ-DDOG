using System;
using System.Threading;
using System.Threading.Tasks;
using Serilog;
using ReceiverWebApp.Models;

namespace ReceiverWebApp.Services
{
    /// <summary>
    /// Continuously polls MSMQ using synchronous Receive() - auto-instrumented by Datadog
    /// </summary>
    public class MessageProcessorService : IDisposable
    {
        private readonly IMsmqReceiverService _msmqReceiverService;
        private Timer _timer;
        private bool _isProcessing;
        private bool _disposed;

        public MessageProcessorService(IMsmqReceiverService msmqReceiverService)
        {
            _msmqReceiverService = msmqReceiverService;
        }

        public void Start()
        {
            Log.Information("Message Processor Service starting...");

            try
            {
                // Initialize the receiver
                _msmqReceiverService.Start();
                Log.Information("MSMQ receiver initialized");
            }
            catch (Exception ex)
            {
                Log.Error(ex, "Failed to initialize MSMQ receiver - service cannot function");
                return;
            }

            Log.Information("Message Processor Service ready - polling MSMQ with auto-instrumented Receive()...");

            // Start timer to continuously poll for messages
            _timer = new Timer(ProcessMessages, null, TimeSpan.Zero, TimeSpan.FromMilliseconds(500));
        }

        private void ProcessMessages(object state)
        {
            if (_isProcessing || _disposed)
            {
                return;
            }

            _isProcessing = true;

            try
            {
                // Call synchronous Receive() - AUTO-INSTRUMENTED by Datadog
                // This will create a msmq.receive span automatically
                var message = _msmqReceiverService.ReceiveMessage();

                if (message != null)
                {
                    ProcessOrder(message).Wait();
                }
            }
            catch (Exception ex)
            {
                Log.Error(ex, "Error in message processing loop");
            }
            finally
            {
                _isProcessing = false;
            }
        }

        private async Task ProcessOrder(OrderMessage order)
        {
            try
            {
                Log.Information("Processing order: {OrderId}", order.OrderId);
                Log.Information("Customer: {CustomerName}, Product: {ProductName}, Quantity: {Quantity}, Amount: ${TotalAmount}", 
                    order.CustomerName, order.ProductName, order.Quantity, order.TotalAmount);

                // Simulate some processing work
                await Task.Delay(TimeSpan.FromSeconds(1));

                // Update order status
                order.Status = "Processed";

                Log.Information("Order {OrderId} processed successfully", order.OrderId);
            }
            catch (Exception ex)
            {
                Log.Error(ex, "Error processing order {OrderId}", order.OrderId);
                order.Status = "Failed";
                throw;
            }
        }

        public void Stop()
        {
            Log.Information("Message Processor Service stopping...");
            _timer?.Change(Timeout.Infinite, Timeout.Infinite);
            Log.Information("Message Processor Service stopped");
        }

        public void Dispose()
        {
            if (!_disposed)
            {
                _disposed = true;
                _timer?.Dispose();
            }
        }
    }
}

