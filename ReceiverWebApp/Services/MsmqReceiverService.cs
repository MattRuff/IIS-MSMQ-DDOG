using Experimental.System.Messaging;
using Newtonsoft.Json;
using ReceiverWebApp.Models;

namespace ReceiverWebApp.Services
{
    public class MsmqReceiverService : IMsmqReceiverService, IDisposable
    {
        private readonly string _queuePath;
        private readonly ILogger<MsmqReceiverService> _logger;
        private MessageQueue? _queue;
        private readonly object _queueLock = new object();

        public MsmqReceiverService(IConfiguration configuration, ILogger<MsmqReceiverService> logger)
        {
            _queuePath = configuration["MSMQ:QueuePath"] ?? @".\private$\OrderQueue";
            _logger = logger;
            InitializeQueue();
        }

        private void InitializeQueue()
        {
            try
            {
                if (!MessageQueue.Exists(_queuePath))
                {
                    _logger.LogWarning($"Queue does not exist: {_queuePath}");
                    return;
                }

                lock (_queueLock)
                {
                    _queue = new MessageQueue(_queuePath);
                    _queue.Formatter = new XmlMessageFormatter(new Type[] { typeof(string) });
                    _logger.LogInformation($"Queue initialized successfully: {_queuePath}");
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error initializing queue");
            }
        }

        public OrderMessage? ReceiveMessage()
        {
            try
            {
                lock (_queueLock)
                {
                    if (_queue == null)
                    {
                        _logger.LogWarning("Queue not initialized, attempting to initialize...");
                        InitializeQueue();
                        if (_queue == null)
                        {
                            return null;
                        }
                    }

                    // Set timeout to 1 second to avoid blocking indefinitely
                    var message = _queue.Receive(TimeSpan.FromSeconds(1));
                    
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
                _logger.LogError(ex, "Error receiving message from queue. Reinitializing queue...");
                
                // Try to recover by reinitializing the queue
                lock (_queueLock)
                {
                    try
                    {
                        _queue?.Dispose();
                        _queue = null;
                    }
                    catch { }
                    
                    InitializeQueue();
                }
                
                return null;
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

                lock (_queueLock)
                {
                    if (_queue == null)
                    {
                        return 0;
                    }
                    
                    return _queue.GetAllMessages().Length;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting message count");
                return 0;
            }
        }

        public void Dispose()
        {
            lock (_queueLock)
            {
                try
                {
                    _queue?.Dispose();
                    _queue = null;
                    _logger.LogInformation("Queue disposed successfully");
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error disposing queue");
                }
            }
        }
    }
}

