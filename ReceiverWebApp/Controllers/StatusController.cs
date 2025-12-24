using System;
using System.Web.Http;
using Serilog;
using ReceiverWebApp.Services;

namespace ReceiverWebApp.Controllers
{
    [RoutePrefix("api/status")]
    public class StatusController : ApiController
    {
        private readonly IMsmqReceiverService _msmqReceiverService;

        public StatusController(IMsmqReceiverService msmqReceiverService)
        {
            _msmqReceiverService = msmqReceiverService;
        }

        [HttpGet]
        [Route("health")]
        public IHttpActionResult Health()
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

        [HttpGet]
        [Route("queue-status")]
        public IHttpActionResult QueueStatus()
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
                Log.Error(ex, "Error getting queue status");
                return Content(System.Net.HttpStatusCode.InternalServerError, new
                {
                    success = false,
                    message = "Error getting queue status",
                    error = ex.Message
                });
            }
        }
    }
}

