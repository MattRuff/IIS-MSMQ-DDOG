using ReceiverWebApp.Models;

namespace ReceiverWebApp.Services
{
    public interface IMsmqReceiverService
    {
        void Start();
        OrderMessage? ReceiveMessage();
        bool IsQueueAvailable();
        int GetMessageCount();
    }
}

