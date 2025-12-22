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
            _logger.LogInformation($"MsmqReceiverService initialized with queue path: {_queuePath}");
        }

        public OrderMessage? ReceiveMessage()
        {
            MessageQueue? tempQueue = null;
            
            try
            {
                if (!MessageQueue.Exists(_queuePath))
                {
                    _logger.LogWarning($"Queue does not exist: {_queuePath}");
                    return null;
                }

                // Create a fresh queue instance for each receive operation
                // This avoids the handle corruption issue in Experimental.System.Messaging
                tempQueue = new MessageQueue(_queuePath);
                tempQueue.Formatter = new XmlMessageFormatter(new Type[] { typeof(string) });

                // Try to peek first to see if there are messages
                try
                {
                    tempQueue.Peek(TimeSpan.FromMilliseconds(100));
                }
                catch (MessageQueueException peekEx) when (peekEx.MessageQueueErrorCode == MessageQueueErrorCode.IOTimeout)
                {
                    // No messages available
                    return null;
                }

                // If peek succeeded, receive the message
                var message = tempQueue.Receive(TimeSpan.FromSeconds(1));
                
                if (message.Body is string jsonMessage)
                {
                    var order = JsonConvert.DeserializeObject<OrderMessage>(jsonMessage);
                    _logger.LogInformation($"Message received successfully. OrderId: {order?.OrderId}");
                    return order;
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
                return null;
            }
            finally
            {
                // Always dispose the temp queue
                try
                {
                    tempQueue?.Dispose();
                }
                catch { }
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
            MessageQueue? tempQueue = null;
            
            try
            {
                if (!MessageQueue.Exists(_queuePath))
                {
                    return 0;
                }

                tempQueue = new MessageQueue(_queuePath);
                return tempQueue.GetAllMessages().Length;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting message count");
                return 0;
            }
            finally
            {
                try
                {
                    tempQueue?.Dispose();
                }
                catch { }
            }
        }
    }
}

