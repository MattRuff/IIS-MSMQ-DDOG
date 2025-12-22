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
            // Retry up to 3 times to work around Experimental.System.Messaging bugs
            for (int attempt = 1; attempt <= 3; attempt++)
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

                    // Receive directly with short timeout
                    var message = tempQueue.Receive(TimeSpan.FromMilliseconds(500));
                    
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
                catch (MessageQueueException mqex) when (mqex.MessageQueueErrorCode == MessageQueueErrorCode.InvalidHandle || 
                                                          mqex.ErrorCode == -2147467259) // 0x80004005
                {
                    // Handle corruption - very common with Experimental.System.Messaging
                    if (attempt < 3)
                    {
                        _logger.LogWarning($"Queue handle error on attempt {attempt}, retrying...");
                        Thread.Sleep(100 * attempt); // Exponential backoff
                        continue;
                    }
                    else
                    {
                        _logger.LogError(mqex, "Queue handle error after 3 attempts");
                        return null;
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, $"Error receiving message from queue (attempt {attempt})");
                    if (attempt < 3)
                    {
                        Thread.Sleep(100 * attempt);
                        continue;
                    }
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

