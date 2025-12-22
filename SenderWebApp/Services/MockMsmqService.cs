using System.Collections.Concurrent;
using Microsoft.Extensions.Logging;
using SenderWebApp.Models;

namespace SenderWebApp.Services
{
    /// <summary>
    /// Mock MSMQ service for local testing without Windows MSMQ
    /// This uses an in-memory queue instead of real MSMQ
    /// </summary>
    public class MockMsmqService : IMsmqService
    {
        private readonly ILogger<MockMsmqService> _logger;
        private static readonly ConcurrentQueue<OrderMessage> _mockQueue = new();

        public MockMsmqService(ILogger<MockMsmqService> logger)
        {
            _logger = logger;
            _logger.LogWarning("⚠️  Using MOCK MSMQ Service - messages stored in memory only!");
        }

        public void SendMessage(OrderMessage message)
        {
            _mockQueue.Enqueue(message);
            _logger.LogInformation($"[MOCK] Message sent to in-memory queue. OrderId: {message.OrderId}");
            _logger.LogInformation($"[MOCK] Queue depth: {_mockQueue.Count}");
        }

        public bool IsQueueAvailable()
        {
            _logger.LogInformation("[MOCK] Queue is always available (in-memory)");
            return true;
        }

        public static int GetQueueCount() => _mockQueue.Count;
        
        public static bool TryDequeue(out OrderMessage? message)
        {
            return _mockQueue.TryDequeue(out message);
        }
    }
}

