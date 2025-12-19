using ReceiverWebApp.Models;

namespace ReceiverWebApp.Services
{
    public interface IMsmqReceiverService
    {
        OrderMessage? ReceiveMessage();
        bool IsQueueAvailable();
        int GetMessageCount();
    }
}

