using System;
using System.Messaging;
using Newtonsoft.Json;
using Serilog;
using ReceiverWebApp.Models;

namespace ReceiverWebApp.Services
{
    /// <summary>
    /// MSMQ Receiver with SYNCHRONOUS Receive() - Auto-instrumented by Datadog
    /// 
    /// This uses System.Messaging.MessageQueue.Receive() which is automatically
    /// instrumented by Datadog's .NET tracer. No manual instrumentation needed.
    /// </summary>
    public class MsmqReceiverService : IMsmqReceiverService, IDisposable
    {
        private readonly string _queuePath;
        private MessageQueue _queue;

        public MsmqReceiverService()
        {
            _queuePath = @".\private$\OrderQueue";
            Log.Information("MsmqReceiverService initialized with SYNCHRONOUS Receive() for auto-instrumentation. Queue: {QueuePath}", _queuePath);
        }

        public void Start()
        {
            if (!MessageQueue.Exists(_queuePath))
            {
                Log.Warning("Queue does not exist: {QueuePath}", _queuePath);
                throw new InvalidOperationException($"Queue does not exist: {_queuePath}. Ensure the Sender application has created the queue.");
            }

            try
            {
                _queue = new MessageQueue(_queuePath);
                _queue.Formatter = new XmlMessageFormatter(new Type[] { typeof(string) });
                
                Log.Information("MSMQ receiver initialized - ready for synchronous Receive() calls");
            }
            catch (Exception ex)
            {
                Log.Error(ex, "Failed to initialize MSMQ receiver");
                throw;
            }
        }

        /// <summary>
        /// Synchronously receives a message from MSMQ with a timeout.
        /// This method is AUTO-INSTRUMENTED by Datadog - creates msmq.receive spans automatically.
        /// </summary>
        public OrderMessage ReceiveMessage()
        {
            try
            {
                // Synchronous receive with 1 second timeout
                // Datadog automatically instruments MessageQueue.Receive()
                var message = _queue.Receive(TimeSpan.FromSeconds(1));
                
                if (message != null)
                {
                    var jsonMessage = message.Body.ToString();
                    var order = JsonConvert.DeserializeObject<OrderMessage>(jsonMessage);
                    
                    if (order != null)
                    {
                        Log.Information("Message received from MSMQ. OrderId: {OrderId}", order.OrderId);
                        return order;
                    }
                }
            }
            catch (MessageQueueException ex) when (ex.MessageQueueErrorCode == MessageQueueErrorCode.IOTimeout)
            {
                // Timeout is normal - no message available
                return null;
            }
            catch (Exception ex)
            {
                Log.Error(ex, "Error receiving message from queue");
            }
            
            return null;
        }

        public bool IsQueueAvailable()
        {
            try
            {
                return MessageQueue.Exists(_queuePath);
            }
            catch
            {
                return false;
            }
        }

        public int GetMessageCount()
        {
            try
            {
                if (_queue != null)
                {
                    return _queue.GetAllMessages().Length;
                }
            }
            catch (Exception ex)
            {
                Log.Warning(ex, "Could not get message count");
            }
            
            return 0;
        }

        public void Dispose()
        {
            if (_queue != null)
            {
                _queue.Close();
                _queue.Dispose();
                _queue = null;
            }
        }
    }
}
