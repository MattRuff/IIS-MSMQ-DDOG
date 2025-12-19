using Experimental.System.Messaging;
using Newtonsoft.Json;
using SenderWebApp.Models;

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
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error sending message. OrderId: {message.OrderId}");
                throw;
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

