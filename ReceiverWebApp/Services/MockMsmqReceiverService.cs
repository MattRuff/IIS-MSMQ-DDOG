using System.Collections.Concurrent;
using Serilog;
using SenderWebApp.Services; // Access the MockMsmqService's queue
using OrderMessageSender = SenderWebApp.Models.OrderMessage;
using OrderMessageReceiver = ReceiverWebApp.Models.OrderMessage;

namespace ReceiverWebApp.Services
{
    public class MockMsmqReceiverService : IMsmqReceiverService
    {
        private readonly ConcurrentQueue<OrderMessageSender> _queue;

        public MockMsmqReceiverService()
        {
            // Share the same in-memory queue as MockMsmqService
            _queue = MockMsmqService.InMemoryQueue;
            Log.Information("MockMsmqReceiverService initialized - Using shared in-memory queue");
        }

        public void Start()
        {
            // No-op for mock - queue is already available
        }

        public OrderMessageReceiver ReceiveMessage()
        {
            OrderMessageSender message;
            if (_queue.TryDequeue(out message))
            {
                // Convert from Sender model to Receiver model
                return new OrderMessageReceiver
                {
                    OrderId = message.OrderId,
                    CustomerName = message.CustomerName,
                    ProductName = message.ProductName,
                    Quantity = message.Quantity,
                    TotalAmount = message.TotalAmount,
                    OrderDate = message.OrderDate,
                    Status = message.Status
                };
            }
            return null;
        }

        public bool IsQueueAvailable()
        {
            return true; // Mock queue is always "available"
        }

        public int GetMessageCount()
        {
            return _queue.Count;
        }
    }
}
