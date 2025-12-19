var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Add MSMQ Service
// REAL MSMQ MODE (Windows only) - Default for customer demos
builder.Services.AddSingleton<SenderWebApp.Services.IMsmqService, SenderWebApp.Services.MsmqService>();

// MOCK MODE (works on Mac/Linux/Windows without MSMQ) - for testing IIS/API only
// Uncomment this and comment out MsmqService above to use Mock mode
// builder.Services.AddSingleton<SenderWebApp.Services.IMsmqService, SenderWebApp.Services.MockMsmqService>();

var app = builder.Build();

// Configure the HTTP request pipeline.
app.UseSwagger();
app.UseSwaggerUI();

app.UseAuthorization();

app.MapControllers();

// Add a simple health check endpoint
app.MapGet("/", () => Results.Ok(new { 
    service = "Sender Web App",
    status = "Running",
    timestamp = DateTime.UtcNow
}));

app.Run();

