using System;
using System.Collections.Generic;
using System.Messaging;
using Newtonsoft.Json;
using Serilog;
using ReceiverWebApp.Models;

namespace ReceiverWebApp.Services
{
    /// <summary>
    /// MSMQ Receiver with EVENT-DRIVEN architecture
    /// 
    /// PROBLEM: Synchronous polling in tight loop causes handle corruption under LocalSystem
    /// SOLUTION: Use async BeginReceive/ReceiveCompleted event pattern - MSMQ manages handle lifecycle
    /// 
    /// This approach:
    /// - No tight polling loop = no handle churn
    /// - MSMQ internally manages the receive handle
    /// - Messages are queued in-memory when received
    /// - Background service pulls from in-memory queue (not MSMQ directly)
    /// </summary>
    public class MsmqReceiverService : IMsmqReceiverService, IDisposable
    {
        private readonly string _queuePath;
        private readonly object _queueLock = new object();
        private readonly Queue<OrderMessage> _receivedMessages = new Queue<OrderMessage>();
        private readonly object _messagesLock = new object();
        
        private MessageQueue _queue;
        private bool _isStarted = false;

        public MsmqReceiverService()
        {
            _queuePath = @".\private$\OrderQueue";
            Log.Information("MsmqReceiverService initialized with EVENT-DRIVEN architecture. Queue: {QueuePath}", _queuePath);
        }

        public void Start()
        {
            lock (_queueLock)
            {
                if (_isStarted)
                {
                    Log.Warning("Service already started, ignoring duplicate Start() call");
                    return;
                }

                if (!MessageQueue.Exists(_queuePath))
                {
                    Log.Warning("Queue does not exist: {QueuePath}", _queuePath);
                    throw new InvalidOperationException($"Queue does not exist: {_queuePath}. Ensure the Sender application has created the queue.");
                }

                try
                {
                    _queue = new MessageQueue(_queuePath);
                    _queue.Formatter = new XmlMessageFormatter(new Type[] { typeof(string) });
                    
                    // Register event handler for async message receive
                    _queue.ReceiveCompleted += OnReceiveCompleted;
                    
                    // Start async receive operation
                    _queue.BeginReceive();
                    
                    _isStarted = true;
                    Log.Information("MSMQ receiver started with event-driven processing");
                }
                catch (Exception ex)
                {
                    Log.Error(ex, "Failed to start MSMQ receiver");
                    throw;
                }
            }
        }

        /// <summary>
        /// Called by MSMQ when a message is available
        /// </summary>
        private void OnReceiveCompleted(object sender, ReceiveCompletedEventArgs e)
        {
            try
            {
                lock (_queueLock)
                {
                    // End the async receive and get the message
                    var message = _queue.EndReceive(e.AsyncResult);
                    
                    // Deserialize
                    var jsonMessage = message.Body.ToString();
                    var order = JsonConvert.DeserializeObject<OrderMessage>(jsonMessage);
                    
                    if (order != null)
                    {
                        // Store in in-memory queue for background processor
                        lock (_messagesLock)
                        {
                            _receivedMessages.Enqueue(order);
                        }
                        
                        Log.Information("Message received from MSMQ and enqueued. OrderId: {OrderId}", order.OrderId);
                    }
                    
                    // Start waiting for the next message
                    _queue.BeginReceive();
                }
            }
            catch (Exception ex)
            {
                Log.Error(ex, "Error processing received message");
                
                // Try to restart receiving despite the error
                try
                {
                    lock (_queueLock)
                    {
                        _queue.BeginReceive();
                    }
                }
                catch (Exception innerEx)
                {
                    Log.Error(innerEx, "Failed to restart receiving after error");
                }
            }
        }

        public OrderMessage ReceiveMessage()
        {
            lock (_messagesLock)
            {
                if (_receivedMessages.Count > 0)
                {
                    return _receivedMessages.Dequeue();
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
            catch
            {
                return false;
            }
        }

        public int GetMessageCount()
        {
            lock (_messagesLock)
            {
                return _receivedMessages.Count;
            }
        }

        public void Dispose()
        {
            lock (_queueLock)
            {
                if (_queue != null)
                {
                    _queue.ReceiveCompleted -= OnReceiveCompleted;
                    _queue.Close();
                    _queue.Dispose();
                    _queue = null;
                }
            }
        }
    }
}
