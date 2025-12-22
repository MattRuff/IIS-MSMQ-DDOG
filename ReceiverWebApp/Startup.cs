using System;
using System.Linq;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Newtonsoft.Json;
using ReceiverWebApp.Services;

namespace ReceiverWebApp
{
    public class Startup
    {
        public Startup(IConfiguration configuration)
        {
            Configuration = configuration;
        }

        public IConfiguration Configuration { get; }

        // This method gets called by the runtime. Use this method to add services to the container.
        public void ConfigureServices(IServiceCollection services)
        {
            services.AddMvc().SetCompatibilityVersion(Microsoft.AspNetCore.Mvc.CompatibilityVersion.Version_2_2);
            
            // Add Swagger
            services.AddSwaggerGen();

            // Add MSMQ Receiver Service
            // REAL MSMQ MODE (Windows only) - Default for customer demos
            services.AddSingleton<IMsmqReceiverService, MsmqReceiverService>();

            // MOCK MODE (works on Mac/Linux/Windows without MSMQ) - for testing IIS/API only
            // Uncomment this and comment out MsmqReceiverService above to use Mock mode
            // services.AddSingleton<IMsmqReceiverService, MockMsmqReceiverService>();

            // Add the background service that processes messages
            services.AddHostedService<MessageProcessorService>();
        }

        // This method gets called by the runtime. Use this method to configure the HTTP request pipeline.
        public void Configure(IApplicationBuilder app, IHostingEnvironment env)
        {
            // Configure the HTTP request pipeline.
            app.UseSwagger();
            app.UseSwaggerUI(c =>
            {
                c.SwaggerEndpoint("/swagger/v1/swagger.json", "Receiver API V1");
            });

            // Add a simple health check endpoint with version BEFORE UseMvc
            app.MapWhen(context => context.Request.Path == "/", appBuilder =>
            {
                appBuilder.Run(async context =>
                {
                    var gitCommitHash = System.Reflection.Assembly.GetExecutingAssembly()
                        .GetCustomAttributes(typeof(System.Reflection.AssemblyMetadataAttribute), false)
                        .Cast<System.Reflection.AssemblyMetadataAttribute>()
                        .FirstOrDefault(a => a.Key == "GitCommitHash")?.Value ?? "unknown";
                    
                    var response = new
                    {
                        service = "Receiver Web App",
                        status = "Running",
                        version = gitCommitHash,
                        timestamp = DateTime.UtcNow
                    };
                    
                    context.Response.ContentType = "application/json";
                    await context.Response.WriteAsync(JsonConvert.SerializeObject(response));
                });
            });

            app.UseMvc();
        }
    }
}
