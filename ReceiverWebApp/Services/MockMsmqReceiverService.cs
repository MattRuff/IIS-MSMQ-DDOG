using System.Collections.Concurrent;
using Microsoft.Extensions.Logging;
using ReceiverWebApp.Models;

namespace ReceiverWebApp.Services
{
    /// <summary>
    /// Mock MSMQ receiver service for local testing without Windows MSMQ
    /// This uses an in-memory queue instead of real MSMQ
    /// </summary>
    public class MockMsmqReceiverService : IMsmqReceiverService
    {
        private readonly ILogger<MockMsmqReceiverService> _logger;
        private static readonly ConcurrentQueue<OrderMessage> _mockQueue = new ConcurrentQueue<OrderMessage>();

        public MockMsmqReceiverService(ILogger<MockMsmqReceiverService> logger)
        {
            _logger = logger;
            _logger.LogWarning("⚠️  Using MOCK MSMQ Receiver Service - messages from in-memory queue only!");
        }

        public void Start()
        {
            _logger.LogInformation("[MOCK] Start() called - no-op for mock service");
        }

        public OrderMessage ReceiveMessage()
        {
            if (_mockQueue.TryDequeue(out var message))
            {
                _logger.LogInformation($"[MOCK] Message received from in-memory queue. OrderId: {message?.OrderId}");
                return message;
            }
            
            // No messages available
            return null;
        }

        public bool IsQueueAvailable()
        {
            _logger.LogInformation("[MOCK] Queue is always available (in-memory)");
            return true;
        }

        public int GetMessageCount()
        {
            var count = _mockQueue.Count;
            _logger.LogInformation($"[MOCK] Messages in queue: {count}");
            return count;
        }

        public static void EnqueueMessage(OrderMessage message)
        {
            _mockQueue.Enqueue(message);
        }
    }
}

