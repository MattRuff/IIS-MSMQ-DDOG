using System;
using System.Web.Http;
using Serilog;
using SenderWebApp.Models;
using SenderWebApp.Services;

namespace SenderWebApp.Controllers
{
    [RoutePrefix("api/order")]
    public class OrderController : ApiController
    {
        private readonly IMsmqService _msmqService;

        public OrderController(IMsmqService msmqService)
        {
            _msmqService = msmqService;
        }

        [HttpPost]
        [Route("")]
        public IHttpActionResult CreateOrder([FromBody] OrderMessage order)
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

                Log.Information("Received order request: {OrderId}", order.OrderId);

                // Send message to MSMQ
                _msmqService.SendMessage(order);

                Log.Information("Order {OrderId} sent to queue successfully", order.OrderId);

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
                Log.Error(ex, "Error processing order");
                return Content(System.Net.HttpStatusCode.InternalServerError, new
                {
                    success = false,
                    message = "Error processing order",
                    error = ex.Message
                });
            }
        }

        [HttpGet]
        [Route("health")]
        public IHttpActionResult Health()
        {
            var queueAvailable = _msmqService.IsQueueAvailable();
            return Ok(new
            {
                service = "Sender Web App",
                queueAvailable = queueAvailable,
                timestamp = DateTime.UtcNow
            });
        }

        [HttpGet]
        [Route("test")]
        public IHttpActionResult SendTestOrder()
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
                Log.Error(ex, "Error sending test order");
                return Content(System.Net.HttpStatusCode.InternalServerError, new
                {
                    success = false,
                    message = "Error sending test order",
                    error = ex.Message
                });
            }
        }
    }
}

