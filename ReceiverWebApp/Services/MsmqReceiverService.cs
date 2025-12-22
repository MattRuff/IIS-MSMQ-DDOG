using Experimental.System.Messaging;
using Newtonsoft.Json;
using ReceiverWebApp.Models;

namespace ReceiverWebApp.Services
{
    /// <summary>
    /// MSMQ Receiver with periodic queue refresh strategy
    /// Key insight: Works in console mode, fails in service due to rapid queue churn
    /// Solution: Keep queue alive longer, refresh periodically to prevent handle corruption
    /// </summary>
    public class MsmqReceiverService : IMsmqReceiverService, IDisposable
    {
        private readonly string _queuePath;
        private readonly ILogger<MsmqReceiverService> _logger;
        private readonly object _queueLock = new object();
        
        private MessageQueue? _queue;
        private int _operationsSinceRefresh = 0;
        private DateTime _lastRefresh = DateTime.UtcNow;
        
        private const int MAX_OPERATIONS_BEFORE_REFRESH = 50; // Refresh every 50 operations
        private static readonly TimeSpan MAX_TIME_BEFORE_REFRESH = TimeSpan.FromMinutes(2); // Or every 2 minutes

        public MsmqReceiverService(IConfiguration configuration, ILogger<MsmqReceiverService> logger)
        {
            _queuePath = configuration["MSMQ:QueuePath"] ?? @".\private$\OrderQueue";
            _logger = logger;
            _logger.LogInformation($"MsmqReceiverService initialized with periodic refresh strategy. Queue: {_queuePath}");
            InitializeQueue();
        }

        private void InitializeQueue()
        {
            lock (_queueLock)
            {
                try
                {
                    // Dispose old queue if exists
                    if (_queue != null)
                    {
                        try
                        {
                            _queue.Dispose();
                            _logger.LogInformation("Disposed old queue instance");
                        }
                        catch (Exception ex)
                        {
                            _logger.LogWarning(ex, "Error disposing old queue");
                        }
                    }

                    if (!MessageQueue.Exists(_queuePath))
                    {
                        _logger.LogWarning($"Queue does not exist: {_queuePath}");
                        _queue = null;
                        return;
                    }

                    // Create new queue instance
                    _queue = new MessageQueue(_queuePath);
                    _queue.Formatter = new XmlMessageFormatter(new Type[] { typeof(string) });
                    
                    _operationsSinceRefresh = 0;
                    _lastRefresh = DateTime.UtcNow;
                    
                    _logger.LogInformation("Queue initialized successfully");
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error initializing queue");
                    _queue = null;
                }
            }
        }

        private bool ShouldRefreshQueue()
        {
            return _operationsSinceRefresh >= MAX_OPERATIONS_BEFORE_REFRESH ||
                   (DateTime.UtcNow - _lastRefresh) >= MAX_TIME_BEFORE_REFRESH;
        }

        public OrderMessage? ReceiveMessage()
        {
            lock (_queueLock)
            {
                try
                {
                    // Check if we need to refresh the queue
                    if (ShouldRefreshQueue())
                    {
                        _logger.LogInformation($"Refreshing queue (operations: {_operationsSinceRefresh}, age: {(DateTime.UtcNow - _lastRefresh).TotalSeconds:F0}s)");
                        InitializeQueue();
                    }

                    // Ensure queue is available
                    if (_queue == null)
                    {
                        _logger.LogWarning("Queue not initialized, attempting to initialize...");
                        InitializeQueue();
                        if (_queue == null)
                        {
                            return null;
                        }
                    }

                    _operationsSinceRefresh++;

                    // Receive message with timeout
                    var message = _queue.Receive(TimeSpan.FromMilliseconds(500));
                    
                    if (message.Body is string jsonMessage)
                    {
                        var order = JsonConvert.DeserializeObject<OrderMessage>(jsonMessage);
                        _logger.LogInformation($"Message received successfully. OrderId: {order?.OrderId}");
                        return order;
                    }
                    
                    return null;
                }
                catch (MessageQueueException mqex) when (mqex.MessageQueueErrorCode == MessageQueueErrorCode.IOTimeout)
                {
                    // No messages available - this is normal
                    _operationsSinceRefresh++;
                    return null;
                }
                catch (MessageQueueException mqex) when (mqex.ErrorCode == unchecked((int)0x80004005))
                {
                    // Handle corruption detected - force refresh
                    _logger.LogWarning("Handle corruption detected (0x80004005), forcing queue refresh");
                    InitializeQueue();
                    return null;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error receiving message from queue");
                    
                    // On any error, try to refresh the queue
                    try
                    {
                        InitializeQueue();
                    }
                    catch (Exception refreshEx)
                    {
                        _logger.LogError(refreshEx, "Failed to refresh queue after error");
                    }
                    
                    return null;
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

        public int GetMessageCount()
        {
            lock (_queueLock)
            {
                try
                {
                    if (_queue == null || !MessageQueue.Exists(_queuePath))
                    {
                        return 0;
                    }

                    return _queue.GetAllMessages().Length;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error getting message count");
                    return 0;
                }
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
