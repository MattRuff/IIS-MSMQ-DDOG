using System;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using ReceiverWebApp.Services;

namespace ReceiverWebApp.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class StatusController : ControllerBase
    {
        private readonly IMsmqReceiverService _msmqReceiverService;
        private readonly ILogger<StatusController> _logger;

        public StatusController(IMsmqReceiverService msmqReceiverService, ILogger<StatusController> logger)
        {
            _msmqReceiverService = msmqReceiverService;
            _logger = logger;
        }

        [HttpGet("health")]
        public IActionResult Health()
        {
            var queueAvailable = _msmqReceiverService.IsQueueAvailable();
            var messageCount = _msmqReceiverService.GetMessageCount();

            return Ok(new
            {
                service = "Receiver Web App",
                queueAvailable = queueAvailable,
                messagesInQueue = messageCount,
                timestamp = DateTime.UtcNow
            });
        }

        [HttpGet("queue-status")]
        public IActionResult QueueStatus()
        {
            try
            {
                var messageCount = _msmqReceiverService.GetMessageCount();
                var queueAvailable = _msmqReceiverService.IsQueueAvailable();

                return Ok(new
                {
                    queueAvailable = queueAvailable,
                    messageCount = messageCount,
                    timestamp = DateTime.UtcNow
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting queue status");
                return StatusCode(500, new
                {
                    success = false,
                    message = "Error getting queue status",
                    error = ex.Message
                });
            }
        }
    }
}

