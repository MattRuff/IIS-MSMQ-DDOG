using System.Runtime.InteropServices;
using System.Text;

namespace ReceiverWebApp.Services;

/// <summary>
/// Native MSMQ Win32 API wrapper using P/Invoke
/// Bypasses the buggy Experimental.System.Messaging library
/// </summary>
public static class NativeMsmq
{
    private const int MQ_OK = 0;
    private const int MQ_ERROR_IO_TIMEOUT = unchecked((int)0xC00E0020);
    private const int MQ_ERROR_QUEUE_NOT_FOUND = unchecked((int)0xC00E0003);
    
    private const int MQ_RECEIVE_ACCESS = 1;
    private const int MQ_DENY_NONE = 0;
    
    private const int MQ_ACTION_RECEIVE = 0;
    private const int MQ_ACTION_PEEK_CURRENT = unchecked((int)0x80000000);
    
    private const int PROPID_M_BODY = 9;
    private const int PROPID_M_BODY_SIZE = 10;
    private const int PROPID_M_BODY_TYPE = 42;
    private const int PROPID_M_LABEL = 11;
    
    private const ushort VT_VECTOR = 0x1000;
    private const ushort VT_UI1 = 17;
    
    [StructLayout(LayoutKind.Sequential)]
    private struct MQMSGPROPS
    {
        public int cProp;
        public IntPtr aPropID;
        public IntPtr aPropVar;
        public IntPtr aStatus;
    }
    
    [StructLayout(LayoutKind.Sequential)]
    private struct MQPROPVARIANT
    {
        public ushort vt;
        public ushort wReserved1;
        public ushort wReserved2;
        public ushort wReserved3;
        public IntPtr ptr;
        public int intValue;
    }
    
    [DllImport("mqrt.dll", CharSet = CharSet.Unicode)]
    private static extern int MQOpenQueue(
        string formatName,
        int access,
        int shareMode,
        out IntPtr hQueue);
    
    [DllImport("mqrt.dll")]
    private static extern int MQCloseQueue(IntPtr hQueue);
    
    [DllImport("mqrt.dll")]
    private static extern int MQReceiveMessage(
        IntPtr hQueue,
        int timeout,
        int action,
        ref MQMSGPROPS msgProps,
        IntPtr overlapped,
        IntPtr receiveCallback,
        IntPtr cursor,
        IntPtr transaction);
    
    [DllImport("mqrt.dll", CharSet = CharSet.Unicode)]
    private static extern int MQPathNameToFormatName(
        string pathName,
        StringBuilder formatName,
        ref int formatNameLength);
    
    public class MsmqMessage
    {
        public string Body { get; set; } = string.Empty;
        public string Label { get; set; } = string.Empty;
    }
    
    public static MsmqMessage? ReceiveMessage(string queuePath, int timeoutMs = 500)
    {
        IntPtr hQueue = IntPtr.Zero;
        IntPtr bodyBuffer = IntPtr.Zero;
        IntPtr labelBuffer = IntPtr.Zero;
        IntPtr propIdArray = IntPtr.Zero;
        IntPtr propVarArray = IntPtr.Zero;
        IntPtr statusArray = IntPtr.Zero;
        
        try
        {
            // Convert queue path to format name
            var formatNameBuilder = new StringBuilder(256);
            int formatNameLength = formatNameBuilder.Capacity;
            int hr = MQPathNameToFormatName(queuePath, formatNameBuilder, ref formatNameLength);
            
            if (hr != MQ_OK)
            {
                if (hr == MQ_ERROR_QUEUE_NOT_FOUND)
                    return null;
                throw new Exception($"MQPathNameToFormatName failed: 0x{hr:X}");
            }
            
            string formatName = formatNameBuilder.ToString();
            
            // Open the queue
            hr = MQOpenQueue(formatName, MQ_RECEIVE_ACCESS, MQ_DENY_NONE, out hQueue);
            if (hr != MQ_OK)
                throw new Exception($"MQOpenQueue failed: 0x{hr:X}");
            
            // Allocate buffers for message body and label
            const int maxBodySize = 4194304; // 4MB max
            const int maxLabelSize = 250;
            
            bodyBuffer = Marshal.AllocHGlobal(maxBodySize);
            labelBuffer = Marshal.AllocHGlobal(maxLabelSize * 2); // Unicode
            
            // Setup property arrays
            propIdArray = Marshal.AllocHGlobal(sizeof(int) * 3);
            propVarArray = Marshal.AllocHGlobal(Marshal.SizeOf<MQPROPVARIANT>() * 3);
            statusArray = Marshal.AllocHGlobal(sizeof(int) * 3);
            
            // Initialize property IDs
            Marshal.WriteInt32(propIdArray, 0 * sizeof(int), PROPID_M_BODY);
            Marshal.WriteInt32(propIdArray, 1 * sizeof(int), PROPID_M_BODY_SIZE);
            Marshal.WriteInt32(propIdArray, 2 * sizeof(int), PROPID_M_LABEL);
            
            // Initialize property variants for body
            var bodyProp = new MQPROPVARIANT
            {
                vt = VT_VECTOR | VT_UI1,
                ptr = bodyBuffer,
                intValue = maxBodySize
            };
            Marshal.StructureToPtr(bodyProp, propVarArray + (0 * Marshal.SizeOf<MQPROPVARIANT>()), false);
            
            // Body size
            var bodySizeProp = new MQPROPVARIANT
            {
                vt = VT_UI1,
                intValue = 0
            };
            Marshal.StructureToPtr(bodySizeProp, propVarArray + (1 * Marshal.SizeOf<MQPROPVARIANT>()), false);
            
            // Label
            var labelProp = new MQPROPVARIANT
            {
                vt = 31, // VT_LPWSTR
                ptr = labelBuffer,
                intValue = maxLabelSize
            };
            Marshal.StructureToPtr(labelProp, propVarArray + (2 * Marshal.SizeOf<MQPROPVARIANT>()), false);
            
            // Setup message properties structure
            var msgProps = new MQMSGPROPS
            {
                cProp = 3,
                aPropID = propIdArray,
                aPropVar = propVarArray,
                aStatus = statusArray
            };
            
            // Receive message
            hr = MQReceiveMessage(hQueue, timeoutMs, MQ_ACTION_RECEIVE, ref msgProps, 
                                 IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero);
            
            if (hr == MQ_ERROR_IO_TIMEOUT)
                return null; // No message available
            
            if (hr != MQ_OK)
                throw new Exception($"MQReceiveMessage failed: 0x{hr:X}");
            
            // Extract body
            var bodyPropResult = Marshal.PtrToStructure<MQPROPVARIANT>(propVarArray);
            int bodySize = Marshal.ReadInt32(propVarArray + Marshal.SizeOf<MQPROPVARIANT>() + 8);
            
            byte[] bodyBytes = new byte[bodySize];
            Marshal.Copy(bodyBuffer, bodyBytes, 0, bodySize);
            string body = Encoding.UTF8.GetString(bodyBytes);
            
            // Extract label
            string label = Marshal.PtrToStringUni(labelBuffer) ?? "";
            
            return new MsmqMessage
            {
                Body = body,
                Label = label
            };
        }
        catch (Exception ex)
        {
            throw new Exception($"Native MSMQ error: {ex.Message}", ex);
        }
        finally
        {
            // Cleanup
            if (hQueue != IntPtr.Zero)
                MQCloseQueue(hQueue);
            
            if (bodyBuffer != IntPtr.Zero)
                Marshal.FreeHGlobal(bodyBuffer);
            
            if (labelBuffer != IntPtr.Zero)
                Marshal.FreeHGlobal(labelBuffer);
            
            if (propIdArray != IntPtr.Zero)
                Marshal.FreeHGlobal(propIdArray);
            
            if (propVarArray != IntPtr.Zero)
                Marshal.FreeHGlobal(propVarArray);
            
            if (statusArray != IntPtr.Zero)
                Marshal.FreeHGlobal(statusArray);
        }
    }
    
    public static bool QueueExists(string queuePath)
    {
        try
        {
            var formatNameBuilder = new StringBuilder(256);
            int formatNameLength = formatNameBuilder.Capacity;
            int hr = MQPathNameToFormatName(queuePath, formatNameBuilder, ref formatNameLength);
            return hr == MQ_OK;
        }
        catch
        {
            return false;
        }
    }
}

