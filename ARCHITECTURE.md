# Architecture Overview

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Datadog APM Platform                             │
│                    (Distributed Trace Visualization)                     │
└─────────────────────────────────────────────────────────────────────────┘
                                     ▲
                                     │ Traces
                                     │
                    ┌────────────────┴────────────────┐
                    │                                  │
┌───────────────────▼──────────────┐  ┌───────────────▼──────────────┐
│    Datadog .NET Tracer           │  │    Datadog .NET Tracer        │
│    (Auto-Instrumentation)        │  │    (Auto-Instrumentation)     │
└───────────────────┬──────────────┘  └───────────────┬───────────────┘
                    │                                  │
┌───────────────────▼──────────────┐  ┌───────────────▼───────────────┐
│      Sender Web Application      │  │    Receiver Web Application    │
│         (Port 5001)              │  │         (Port 5002)            │
│                                  │  │                                │
│  ┌────────────────────────────┐ │  │  ┌──────────────────────────┐ │
│  │   OrderController          │ │  │  │  StatusController        │ │
│  │   - POST /api/order        │ │  │  │  - GET /api/status/health│ │
│  │   - GET /api/order/test    │ │  │  │  - GET /queue-status     │ │
│  │   - GET /api/order/health  │ │  │  └──────────────────────────┘ │
│  └────────────┬───────────────┘ │  │                                │
│               │                  │  │  ┌──────────────────────────┐ │
│               ▼                  │  │  │ MessageProcessorService  │ │
│  ┌────────────────────────────┐ │  │  │  (Background Service)    │ │
│  │     MsmqService            │ │  │  │  - Continuous polling     │ │
│  │  - SendMessage()           │ │  │  │  - Message processing     │ │
│  │  - IsQueueAvailable()      │ │  │  └────────┬─────────────────┘ │
│  └────────────┬───────────────┘ │  │           │                   │
└───────────────┼──────────────────┘  │           ▼                   │
                │                     │  ┌──────────────────────────┐ │
                │                     │  │  MsmqReceiverService     │ │
                │                     │  │  - ReceiveMessage()      │ │
                │                     │  │  - GetMessageCount()     │ │
                │                     │  └────────┬─────────────────┘ │
                │                     └───────────┼───────────────────┘
                │                                 │
                └─────────────────┬───────────────┘
                                  ▼
                    ┌──────────────────────────┐
                    │   Microsoft MSMQ         │
                    │   .\private$\OrderQueue  │
                    │                          │
                    │   - Message persistence  │
                    │   - Guaranteed delivery  │
                    │   - Transaction support  │
                    └──────────────────────────┘
```

## Component Details

### 1. Sender Web Application

**Technology**: ASP.NET Core 6.0 Web API

**Responsibilities**:
- Accept HTTP POST requests with order data
- Serialize order messages to JSON
- Publish messages to MSMQ queue
- Provide health check endpoints

**Key Components**:
- `OrderController`: REST API endpoints
- `MsmqService`: MSMQ message publishing logic
- `OrderMessage`: Data model for orders

**Endpoints**:
- `POST /api/order` - Send custom order
- `GET /api/order/test` - Send test order
- `GET /api/order/health` - Health check
- `GET /swagger` - Swagger UI

### 2. MSMQ (Message Queue)

**Technology**: Microsoft Message Queue

**Configuration**:
- Queue Path: `.\private$\OrderQueue`
- Type: Private queue
- Transactional: Optional
- Recoverable: Yes (messages persist across restarts)

**Features**:
- **Persistence**: Messages survive application/system restarts
- **Guaranteed Delivery**: Messages won't be lost
- **Ordering**: FIFO (First In, First Out)
- **Decoupling**: Sender and receiver run independently

### 3. Receiver Web Application

**Technology**: ASP.NET Core 6.0 Web API + Background Service

**Responsibilities**:
- Poll MSMQ queue for new messages
- Deserialize JSON messages to OrderMessage objects
- Process orders (business logic)
- Provide queue status endpoints

**Key Components**:
- `MessageProcessorService`: Background service (runs continuously)
- `MsmqReceiverService`: MSMQ message consumption logic
- `StatusController`: Status and monitoring endpoints
- `OrderMessage`: Data model for orders

**Endpoints**:
- `GET /api/status/health` - Health check with queue stats
- `GET /api/status/queue-status` - Detailed queue information
- `GET /swagger` - Swagger UI

### 4. Datadog Integration

**Technology**: Datadog .NET Tracer (Single-Step Instrumentation)

**How It Works**:
1. **Profiler Injection**: CLR profiler intercepts method calls
2. **Auto-Instrumentation**: Automatically instruments:
   - ASP.NET Core HTTP requests
   - MSMQ send/receive operations
   - Database calls (if added)
3. **Trace Context Propagation**: Trace IDs pass through MSMQ messages
4. **Agent Communication**: Tracer sends spans to local Datadog Agent
5. **APM Platform**: Agent forwards to Datadog cloud for visualization

**Trace Flow**:
```
HTTP Request → Sender App → MSMQ Send → MSMQ Receive → Receiver App → Processing
     │              │            │             │              │              │
     └──────────────┴────────────┴─────────────┴──────────────┴──────────────┘
                            Single Distributed Trace
```

## Message Flow

### Detailed Flow Diagram

```
1. Client Request
   │
   └──► HTTP POST http://localhost:8081/api/order
        {
          "customerName": "John Doe",
          "productName": "Widget",
          "quantity": 5,
          "totalAmount": 149.99
        }

2. Sender App Processing
   │
   ├──► OrderController receives request
   │    │
   │    ├──► Validate order data
   │    │
   │    ├──► Generate Order ID (if not provided)
   │    │
   │    └──► Call MsmqService.SendMessage()
   │
   └──► MsmqService
        │
        ├──► Serialize order to JSON
        │
        ├──► Create MSMQ Message
        │    - Body: JSON string
        │    - Label: "Order-{OrderId}"
        │    - Recoverable: true
        │
        ├──► Send to queue: .\private$\OrderQueue
        │
        └──► Return success response to client

3. MSMQ Storage
   │
   └──► Message persisted in queue
        - Waiting for receiver to pick it up
        - Survives app/system restarts

4. Receiver App Polling
   │
   ├──► MessageProcessorService (Background Service)
   │    │
   │    └──► Continuous loop:
   │         - Call MsmqReceiverService.ReceiveMessage()
   │         - Wait 1 second for message (timeout)
   │         - If no message: sleep 2 seconds, retry
   │         - If message received: process it
   │
   └──► MsmqReceiverService
        │
        ├──► Call MessageQueue.Receive(1 second timeout)
        │
        ├──► Message found!
        │
        ├──► Deserialize JSON to OrderMessage
        │
        └──► Return to MessageProcessorService

5. Message Processing
   │
   ├──► MessageProcessorService.ProcessOrder()
   │    │
   │    ├──► Log order details
   │    │
   │    ├──► Simulate processing (1 second delay)
   │    │
   │    ├──► Update order status to "Processed"
   │    │
   │    └──► Log completion
   │
   └──► Loop back to step 4 (poll for next message)
```

## Data Model

### OrderMessage

```csharp
public class OrderMessage
{
    public string OrderId { get; set; }        // Unique identifier
    public string CustomerName { get; set; }   // Customer name
    public string ProductName { get; set; }    // Product name
    public int Quantity { get; set; }          // Order quantity
    public decimal TotalAmount { get; set; }   // Total price
    public DateTime OrderDate { get; set; }    // When order was placed
    public string Status { get; set; }         // Pending/Processed/Failed
}
```

### Example JSON Message in MSMQ

```json
{
  "orderId": "a1b2c3d4-e5f6-7890-abcd-1234567890ab",
  "customerName": "John Doe",
  "productName": "Premium Widget",
  "quantity": 5,
  "totalAmount": 299.99,
  "orderDate": "2024-12-19T10:30:00Z",
  "status": "Pending"
}
```

## Distributed Tracing Details

### Trace Structure in Datadog

```
Trace ID: abc123...
│
├─ Span 1: HTTP POST /api/order
│  ├─ Service: msmq-sender
│  ├─ Duration: 25ms
│  ├─ Tags:
│  │  ├─ http.method: POST
│  │  ├─ http.url: /api/order
│  │  ├─ http.status_code: 200
│  │  └─ order.id: a1b2c3d4...
│  │
│  └─ Span 2: msmq.send
│     ├─ Service: msmq-sender
│     ├─ Duration: 15ms
│     ├─ Tags:
│     │  ├─ msmq.queue: .\private$\OrderQueue
│     │  ├─ msmq.operation: send
│     │  ├─ order.id: a1b2c3d4...
│     │  └─ order.customer: John Doe
│     │
│     └─ Span 3: msmq.receive
│        ├─ Service: msmq-receiver
│        ├─ Duration: 1050ms
│        ├─ Tags:
│        │  ├─ msmq.queue: .\private$\OrderQueue
│        │  ├─ msmq.operation: receive
│        │  └─ order.id: a1b2c3d4...
│        │
│        └─ Span 4: order.process
│           ├─ Service: msmq-receiver
│           ├─ Duration: 1000ms
│           ├─ Tags:
│           │  ├─ order.id: a1b2c3d4...
│           │  ├─ order.status: Processed
│           │  └─ customer.name: John Doe
```

### Key Metrics Tracked

- **Latency**: Time from HTTP request to order processing completion
- **Throughput**: Orders processed per second
- **Error Rate**: Failed orders vs successful orders
- **Queue Depth**: Messages waiting in MSMQ
- **Processing Time**: Time spent processing each order

## Scalability Considerations

### Current Design (Single Instance)

```
1 Sender → 1 Queue → 1 Receiver
```

### Scaled Design (Multiple Instances)

```
Load Balancer
│
├─► Sender Instance 1 ─┐
├─► Sender Instance 2 ─┼─► MSMQ Queue ─┬─► Receiver Instance 1
└─► Sender Instance 3 ─┘                ├─► Receiver Instance 2
                                         └─► Receiver Instance 3
```

**Benefits**:
- Multiple senders can write to the same queue
- Multiple receivers can read from the same queue (competitive consumers)
- MSMQ handles message distribution automatically
- Datadog traces will show all instances

## Deployment Options

### Option 1: Development (Current)
- Run with `dotnet run`
- Suitable for testing and development
- Easy to debug

### Option 2: IIS Deployment
- Deploy to Windows IIS
- Production-ready
- Better performance
- Requires IIS configuration

### Option 3: Windows Service
- Run as background Windows services
- No IIS required
- Good for message processing workloads

### Option 4: Docker (Advanced)
- Containerize applications
- Requires Windows containers for MSMQ
- Orchestrate with Docker Compose or Kubernetes

## Security Considerations

### Current Implementation
- No authentication on HTTP endpoints
- MSMQ uses Windows security (local only)
- Suitable for sandbox/demo purposes

### Production Recommendations
1. **API Security**:
   - Add authentication (JWT, API keys)
   - Implement authorization
   - Enable HTTPS

2. **MSMQ Security**:
   - Configure queue permissions
   - Use transactional queues
   - Implement message encryption

3. **Network Security**:
   - Use firewalls
   - Restrict port access
   - VPN for remote access

4. **Monitoring**:
   - Use Datadog for full observability
   - Set up alerts for errors
   - Monitor queue depth

## Performance Characteristics

### Expected Performance

| Metric | Value |
|--------|-------|
| Message Send Latency | < 50ms |
| Message Receive Latency | < 100ms |
| Processing Time | 1000ms (simulated) |
| End-to-End Latency | ~1150ms |
| Throughput (Single Receiver) | ~1 msg/sec |
| Queue Capacity | Limited by disk space |

### Bottlenecks

1. **Processing Time**: Currently simulated with 1-second delay
2. **Single Receiver**: Only one background service polling
3. **Sequential Processing**: Messages processed one at a time

### Optimization Strategies

1. **Parallel Processing**: Process multiple messages simultaneously
2. **Multiple Receivers**: Deploy multiple receiver instances
3. **Batch Processing**: Process messages in batches
4. **Async I/O**: Use async/await throughout

## Technology Stack

| Component | Technology | Version |
|-----------|-----------|---------|
| Runtime | .NET | 6.0+ |
| Web Framework | ASP.NET Core | 6.0+ |
| Message Queue | MSMQ | Windows built-in |
| Serialization | Newtonsoft.Json | 13.0.3 |
| Messaging API | System.Messaging | 6.0.0 |
| APM | Datadog .NET Tracer | Latest |
| Documentation | Swagger/OpenAPI | Built-in |

## Future Enhancements

1. **Database Integration**: Add Entity Framework for persistence
2. **Error Handling**: Implement dead-letter queue for failed messages
3. **Retry Logic**: Add exponential backoff for failures
4. **Load Testing**: Add performance testing suite
5. **Metrics**: Add custom Datadog metrics
6. **Logs**: Integrate with Datadog Log Management
7. **Authentication**: Add OAuth2/JWT support
8. **Rate Limiting**: Protect endpoints from abuse
9. **Circuit Breaker**: Handle downstream service failures
10. **Health Checks**: Add ASP.NET Core health check middleware

