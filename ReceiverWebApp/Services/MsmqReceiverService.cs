using System;
using System.Collections.Generic;
using System.Messaging;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
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
        private readonly ILogger<MsmqReceiverService> _logger;
        private readonly object _queueLock = new object();
        private readonly Queue<OrderMessage> _receivedMessages = new Queue<OrderMessage>();
        private readonly object _messagesLock = new object();
        
        private MessageQueue? _queue;
        private bool _isStarted = false;

        public MsmqReceiverService(IConfiguration configuration, ILogger<MsmqReceiverService> _logger)
        {
            _queuePath = configuration["MSMQ:QueuePath"] ?? @".\private$\OrderQueue";
            this._logger = _logger;
            _logger.LogInformation("MsmqReceiverService initialized with EVENT-DRIVEN architecture. Queue: {QueuePath}", _queuePath);
        }

        public void Start()
        {
            lock (_queueLock)
            {
                if (_isStarted)
                {
                    _logger.LogWarning("Service already started, ignoring duplicate Start() call");
                    return;
                }

                try
                {
                    if (!MessageQueue.Exists(_queuePath))
                    {
                        _logger.LogError("Queue does not exist: {QueuePath}", _queuePath);
                        throw new InvalidOperationException($"Queue does not exist: {_queuePath}");
                    }

                    _queue = new MessageQueue(_queuePath)
                    {
                        Formatter = new XmlMessageFormatter(new Type[] { typeof(string) })
                    };

                    // Set up event-driven receive
                    _queue.ReceiveCompleted += OnReceiveCompleted;
                    _queue.BeginReceive();

                    _isStarted = true;
                    _logger.LogInformation("✓ Event-driven message receiver started successfully");
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "✗ Failed to start event-driven receiver");
                    throw;
                }
            }
        }

        private void OnReceiveCompleted(object sender, ReceiveCompletedEventArgs e)
        {
            try
            {
                var queue = (MessageQueue)sender;
                var message = queue.EndReceive(e.AsyncResult);

                if (message?.Body is string jsonBody)
                {
                    var orderMessage = JsonConvert.DeserializeObject<OrderMessage>(jsonBody);
                    if (orderMessage != null)
                    {
                        lock (_messagesLock)
                        {
                            _receivedMessages.Enqueue(orderMessage);
                        }
                        _logger.LogInformation("EVENT: Received order {OrderId}, Customer: {Customer} (In-memory queue: {Count})", 
                            orderMessage.OrderId, orderMessage.CustomerName, _receivedMessages.Count);
                    }
                }

                // Start listening for the next message
                queue.BeginReceive();
            }
            catch (MessageQueueException mqex)
            {
                _logger.LogError(mqex, "MSMQ error in event handler (Code: {Code}, HResult: 0x{HResult:X})", 
                    mqex.MessageQueueErrorCode, mqex.HResult);
                
                // Try to restart receiving
                TryRestartReceiving();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unexpected error in event handler");
                
                // Try to restart receiving
                TryRestartReceiving();
            }
        }

        private void TryRestartReceiving()
        {
            try
            {
                lock (_queueLock)
                {
                    if (_isStarted && _queue != null)
                    {
                        _queue.BeginReceive();
                        _logger.LogInformation("Restarted receiving after error");
                    }
                }
            }
            catch (Exception restartEx)
            {
                _logger.LogError(restartEx, "Failed to restart receiving - service may need manual restart");
            }
        }

        public OrderMessage? ReceiveMessage()
        {
            // This now pulls from the in-memory queue, NOT from MSMQ directly
            lock (_messagesLock)
            {
                if (_receivedMessages.Count > 0)
                {
                    var msg = _receivedMessages.Dequeue();
                    _logger.LogDebug("Dequeued message {OrderId} from in-memory buffer (Remaining: {Count})", 
                        msg.OrderId, _receivedMessages.Count);
                    return msg;
                }
                return null;
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
                    _isStarted = false;
                    if (_queue != null)
                    {
                        _queue.ReceiveCompleted -= OnReceiveCompleted;
                        _queue.Dispose();
                        _queue = null;
                    }
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
