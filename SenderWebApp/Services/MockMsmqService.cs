using System.Collections.Concurrent;
using Serilog;
using SenderWebApp.Models;

namespace SenderWebApp.Services
{
    /// <summary>
    /// Mock MSMQ service for local testing without Windows MSMQ
    /// This uses an in-memory queue instead of real MSMQ
    /// </summary>
    public class MockMsmqService : IMsmqService
    {
        // Public static queue so ReceiverWebApp can access it
        public static readonly ConcurrentQueue<OrderMessage> InMemoryQueue = new ConcurrentQueue<OrderMessage>();

        public MockMsmqService()
        {
            Log.Warning("Using MOCK MSMQ Service - messages stored in memory only!");
        }

        public void SendMessage(OrderMessage message)
        {
            InMemoryQueue.Enqueue(message);
            Log.Information("[MOCK] Message sent to in-memory queue. OrderId: {OrderId}", message.OrderId);
            Log.Information("[MOCK] Queue depth: {QueueDepth}", InMemoryQueue.Count);
        }

        public bool IsQueueAvailable()
        {
            Log.Information("[MOCK] Queue is always available (in-memory)");
            return true;
        }
    }
}
