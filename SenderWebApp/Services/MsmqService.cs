using System;
using System.Messaging;
using Newtonsoft.Json;
using Serilog;
using SenderWebApp.Models;

namespace SenderWebApp.Services
{
    public class MsmqService : IMsmqService
    {
        private readonly string _queuePath;

        public MsmqService()
        {
            _queuePath = @".\private$\OrderQueue";
            EnsureQueueExists();
        }

        private void EnsureQueueExists()
        {
            try
            {
                if (!MessageQueue.Exists(_queuePath))
                {
                    Log.Information("Creating queue: {QueuePath}", _queuePath);
                    MessageQueue.Create(_queuePath);
                    Log.Information("Queue created successfully: {QueuePath}", _queuePath);
                    Log.Information("Note: Permissions for NetworkService should be set by install script");
                }
                else
                {
                    Log.Information("Queue already exists: {QueuePath}", _queuePath);
                }
            }
            catch (Exception ex)
            {
                Log.Error(ex, "Error ensuring queue exists: {QueuePath}", _queuePath);
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
                    Log.Information("Message sent successfully. OrderId: {OrderId}", message.OrderId);
                }
            }
            catch (Exception ex)
            {
                Log.Error(ex, "Error sending message. OrderId: {OrderId}", message.OrderId);
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
                Log.Error(ex, "Error checking queue availability");
                return false;
            }
        }
    }
}

