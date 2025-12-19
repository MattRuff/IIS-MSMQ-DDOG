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
            _logger.LogInformation("Message Processor Service started");

            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    var message = _msmqReceiverService.ReceiveMessage();

                    if (message != null)
                    {
                        await ProcessOrder(message);
                    }
                    else
                    {
                        // No messages available, wait a bit before checking again
                        await Task.Delay(TimeSpan.FromSeconds(2), stoppingToken);
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error in message processing loop");
                    await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
                }
            }

            _logger.LogInformation("Message Processor Service stopped");
        }

        private async Task ProcessOrder(OrderMessage order)
        {
            try
            {
                _logger.LogInformation($"Processing order: {order.OrderId}");
                _logger.LogInformation($"Customer: {order.CustomerName}, Product: {order.ProductName}, Quantity: {order.Quantity}, Amount: ${order.TotalAmount}");

                // Simulate some processing work
                await Task.Delay(TimeSpan.FromSeconds(1));

                // Update order status
                order.Status = "Processed";

                _logger.LogInformation($"Order {order.OrderId} processed successfully");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error processing order {order.OrderId}");
                order.Status = "Failed";
            }
        }
    }
}

