using Microsoft.AspNetCore.Mvc;
using SenderWebApp.Models;
using SenderWebApp.Services;

namespace SenderWebApp.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class OrderController : ControllerBase
    {
        private readonly IMsmqService _msmqService;
        private readonly ILogger<OrderController> _logger;

        public OrderController(IMsmqService msmqService, ILogger<OrderController> logger)
        {
            _msmqService = msmqService;
            _logger = logger;
        }

        [HttpPost]
        public IActionResult CreateOrder([FromBody] OrderMessage order)
        {
            try
            {
                if (string.IsNullOrEmpty(order.OrderId))
                {
                    order.OrderId = Guid.NewGuid().ToString();
                }

                if (order.OrderDate == default)
                {
                    order.OrderDate = DateTime.UtcNow;
                }

                _logger.LogInformation($"Received order request: {order.OrderId}");

                // Send message to MSMQ
                _msmqService.SendMessage(order);

                _logger.LogInformation($"Order {order.OrderId} sent to queue successfully");

                return Ok(new
                {
                    success = true,
                    message = "Order sent to queue successfully",
                    orderId = order.OrderId,
                    timestamp = DateTime.UtcNow
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing order");
                return StatusCode(500, new
                {
                    success = false,
                    message = "Error processing order",
                    error = ex.Message
                });
            }
        }

        [HttpGet("health")]
        public IActionResult Health()
        {
            var queueAvailable = _msmqService.IsQueueAvailable();
            return Ok(new
            {
                service = "Sender Web App",
                queueAvailable = queueAvailable,
                timestamp = DateTime.UtcNow
            });
        }

        [HttpGet("test")]
        public IActionResult SendTestOrder()
        {
            try
            {
                var testOrder = new OrderMessage
                {
                    OrderId = Guid.NewGuid().ToString(),
                    CustomerName = "Test Customer",
                    ProductName = "Test Product",
                    Quantity = 1,
                    TotalAmount = 99.99m,
                    OrderDate = DateTime.UtcNow,
                    Status = "Pending"
                };

                _msmqService.SendMessage(testOrder);

                return Ok(new
                {
                    success = true,
                    message = "Test order sent successfully",
                    order = testOrder
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error sending test order");
                return StatusCode(500, new
                {
                    success = false,
                    message = "Error sending test order",
                    error = ex.Message
                });
            }
        }
    }
}

