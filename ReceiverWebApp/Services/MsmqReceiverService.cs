using Experimental.System.Messaging;
using Newtonsoft.Json;
using ReceiverWebApp.Models;

namespace ReceiverWebApp.Services
{
    public class MsmqReceiverService : IMsmqReceiverService
    {
        private readonly string _queuePath;
        private readonly ILogger<MsmqReceiverService> _logger;

        public MsmqReceiverService(IConfiguration configuration, ILogger<MsmqReceiverService> logger)
        {
            _queuePath = configuration["MSMQ:QueuePath"] ?? @".\private$\OrderQueue";
            _logger = logger;
        }

        public OrderMessage? ReceiveMessage()
        {
            try
            {
                if (!MessageQueue.Exists(_queuePath))
                {
                    _logger.LogWarning($"Queue does not exist: {_queuePath}");
                    return null;
                }

                using (var queue = new MessageQueue(_queuePath))
                {
                    queue.Formatter = new XmlMessageFormatter(new Type[] { typeof(string) });

                    // Set timeout to 1 second to avoid blocking indefinitely
                    var message = queue.Receive(TimeSpan.FromSeconds(1));
                    
                    if (message.Body is string jsonMessage)
                    {
                        var order = JsonConvert.DeserializeObject<OrderMessage>(jsonMessage);
                        _logger.LogInformation($"Message received successfully. OrderId: {order?.OrderId}");
                        return order;
                    }
                }
            }
            catch (MessageQueueException mqex) when (mqex.MessageQueueErrorCode == MessageQueueErrorCode.IOTimeout)
            {
                // No messages available - this is normal
                return null;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error receiving message from queue");
                throw;
            }

            return null;
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

        public int GetMessageCount()
        {
            try
            {
                if (!MessageQueue.Exists(_queuePath))
                {
                    return 0;
                }

                using (var queue = new MessageQueue(_queuePath))
                {
                    return queue.GetAllMessages().Length;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting message count");
                return 0;
            }
        }
    }
}

