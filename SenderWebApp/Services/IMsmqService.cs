using SenderWebApp.Models;

namespace SenderWebApp.Services
{
    public interface IMsmqService
    {
        void SendMessage(OrderMessage message);
        bool IsQueueAvailable();
    }
}

