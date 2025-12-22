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
            _logger.LogInformation($"MsmqReceiverService initialized with Native MSMQ implementation, queue path: {_queuePath}");
        }

        public OrderMessage? ReceiveMessage()
        {
            try
            {
                if (!NativeMsmq.QueueExists(_queuePath))
                {
                    _logger.LogWarning($"Queue does not exist: {_queuePath}");
                    return null;
                }

                // Use native MSMQ Win32 API - completely bypasses buggy Experimental.System.Messaging
                var nativeMessage = NativeMsmq.ReceiveMessage(_queuePath, timeoutMs: 500);
                
                if (nativeMessage == null)
                {
                    // No messages available - normal
                    return null;
                }
                
                // Parse JSON body
                var order = JsonConvert.DeserializeObject<OrderMessage>(nativeMessage.Body);
                
                if (order != null)
                {
                    _logger.LogInformation($"Message received successfully via Native MSMQ. OrderId: {order.OrderId}");
                    return order;
                }
                
                _logger.LogWarning("Received message but failed to deserialize");
                return null;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error receiving message from queue via Native MSMQ");
                return null;
            }
        }

        public bool IsQueueAvailable()
        {
            try
            {
                return NativeMsmq.QueueExists(_queuePath);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error checking queue availability via Native MSMQ");
                return false;
            }
        }

        public int GetMessageCount()
        {
            try
            {
                // Note: Getting count with native API requires enumeration
                // For simplicity, return -1 to indicate "not implemented"
                // The queue works fine, we just can't easily count messages with Win32 API
                _logger.LogWarning("GetMessageCount not implemented with Native MSMQ (requires enumeration)");
                return -1;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting message count");
                return 0;
            }
        }
    }
}

