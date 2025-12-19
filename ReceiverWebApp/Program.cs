var builder = WebApplication.CreateBuilder(args);

// Configure for Windows Service support
builder.Host.UseWindowsService();

// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Add MSMQ Service
// REAL MSMQ MODE (Windows only) - Default for customer demos
builder.Services.AddSingleton<ReceiverWebApp.Services.IMsmqReceiverService, ReceiverWebApp.Services.MsmqReceiverService>();

// MOCK MODE (works on Mac/Linux/Windows without MSMQ) - for testing IIS/API only
// Uncomment this and comment out MsmqReceiverService above to use Mock mode
// builder.Services.AddSingleton<ReceiverWebApp.Services.IMsmqReceiverService, ReceiverWebApp.Services.MockMsmqReceiverService>();

// Add Hosted Service for background processing
builder.Services.AddHostedService<ReceiverWebApp.Services.MessageProcessorService>();

var app = builder.Build();

// Configure the HTTP request pipeline.
app.UseSwagger();
app.UseSwaggerUI();

app.UseAuthorization();

app.MapControllers();

// Add a simple health check endpoint
app.MapGet("/", () => Results.Ok(new { 
    service = "Receiver Web App",
    status = "Running",
    timestamp = DateTime.UtcNow
}));

app.Run();

