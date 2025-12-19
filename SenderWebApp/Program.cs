var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Add MSMQ Service
// MOCK MODE (works on Mac/Linux/Windows without MSMQ) - for testing IIS/API
builder.Services.AddSingleton<SenderWebApp.Services.IMsmqService, SenderWebApp.Services.MockMsmqService>();

// REAL MSMQ MODE (Windows only) - uncomment this line and comment out MockMsmqService above
// builder.Services.AddSingleton<SenderWebApp.Services.IMsmqService, SenderWebApp.Services.MsmqService>();

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

