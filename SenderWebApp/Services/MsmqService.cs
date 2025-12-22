using Experimental.System.Messaging;
using Newtonsoft.Json;
using SenderWebApp.Models;
using Datadog.Trace;

namespace SenderWebApp.Services
{
    public class MsmqService : IMsmqService
    {
        private readonly string _queuePath;
        private readonly ILogger<MsmqService> _logger;

        public MsmqService(IConfiguration configuration, ILogger<MsmqService> logger)
        {
            _queuePath = configuration["MSMQ:QueuePath"] ?? @".\private$\OrderQueue";
            _logger = logger;
            EnsureQueueExists();
        }

        private void EnsureQueueExists()
        {
            try
            {
                if (!MessageQueue.Exists(_queuePath))
                {
                    _logger.LogInformation($"Creating queue: {_queuePath}");
                    MessageQueue.Create(_queuePath);
                    _logger.LogInformation($"Queue created successfully: {_queuePath}");
                    _logger.LogInformation("Note: Permissions for NetworkService should be set by install script");
                }
                else
                {
                    _logger.LogInformation($"Queue already exists: {_queuePath}");
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error ensuring queue exists: {_queuePath}");
                throw;
            }
        }

        public void SendMessage(OrderMessage message)
        {
            // Create a Datadog span for MSMQ send operation
            using (var scope = Tracer.Instance.StartActive("msmq.send"))
            {
                var span = scope.Span;
                span.Type = SpanTypes.MessageBroker;
                span.ResourceName = "send.order";
                span.SetTag("order.id", message.OrderId);
                span.SetTag("order.customer", message.CustomerName);
                span.SetTag("messaging.system", "msmq");
                span.SetTag("messaging.destination", _queuePath);
                span.SetTag("messaging.operation", "send");
                
                try
                {
                    using (var queue = new MessageQueue(_queuePath))
                    {
                        queue.Formatter = new XmlMessageFormatter(new Type[] { typeof(string) });
                        
                        var jsonMessage = JsonConvert.SerializeObject(message);
                        var msmqMessage = new Message(jsonMessage)
                        {
                            Label = $"Order-{message.OrderId}",
                            Recoverable = true // Ensures message persists across reboots
                        };

                        queue.Send(msmqMessage);
                        _logger.LogInformation($"Message sent successfully. OrderId: {message.OrderId}");
                        
                        span.SetTag("message.sent", "true");
                    }
                }
                catch (Exception ex)
                {
                    span.SetException(ex);
                    _logger.LogError(ex, $"Error sending message. OrderId: {message.OrderId}");
                    throw;
                }
            }
        }

        public bool IsQueueAvailable()
        {
            try
            {
                return MessageQueue.Exists(_queuePath);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error checking queue availability");
                return false;
            }
        }
    }
}

