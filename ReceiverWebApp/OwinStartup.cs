using System;
using System.Linq;
using System.Reflection;
using System.Web.Http;
using Owin;
using Swashbuckle.Application;
using ReceiverWebApp.Services;

namespace ReceiverWebApp
{
    public class OwinStartup
    {
        private readonly IMsmqReceiverService _msmqReceiverService;

        public OwinStartup(IMsmqReceiverService msmqReceiverService)
        {
            _msmqReceiverService = msmqReceiverService;
        }

        public void Configuration(IAppBuilder app)
        {
            var config = new HttpConfiguration();

            // Register global Serilog action filter for HTTP request logging
            config.Filters.Add(new SerilogWebApiFilter());

            // Enable attribute routing
            config.MapHttpAttributeRoutes();

            // Add default route
            config.Routes.MapHttpRoute(
                name: "DefaultApi",
                routeTemplate: "api/{controller}/{id}",
                defaults: new { id = RouteParameter.Optional }
            );

            // Configure JSON formatter
            var json = config.Formatters.JsonFormatter;
            json.SerializerSettings.ReferenceLoopHandling = Newtonsoft.Json.ReferenceLoopHandling.Ignore;
            config.Formatters.Remove(config.Formatters.XmlFormatter);

            // Configure dependency injection for controllers
            config.DependencyResolver = new SimpleDependencyResolver(_msmqReceiverService);

            // Enable Swagger
            config.EnableSwagger(c =>
            {
                c.SingleApiVersion("v1", "Receiver API");
                c.IncludeXmlComments(GetXmlCommentsPath());
            })
            .EnableSwaggerUi();

            app.UseWebApi(config);
        }

        private string GetXmlCommentsPath()
        {
            var baseDirectory = AppDomain.CurrentDomain.BaseDirectory;
            var xmlFile = $"{Assembly.GetExecutingAssembly().GetName().Name}.xml";
            return System.IO.Path.Combine(baseDirectory, xmlFile);
        }
    }

    // Simple dependency resolver for Web API 2
    public class SimpleDependencyResolver : System.Web.Http.Dependencies.IDependencyResolver
    {
        private readonly IMsmqReceiverService _msmqReceiverService;

        public SimpleDependencyResolver(IMsmqReceiverService msmqReceiverService)
        {
            _msmqReceiverService = msmqReceiverService;
        }

        public object GetService(Type serviceType)
        {
            if (serviceType == typeof(ReceiverWebApp.Controllers.StatusController))
            {
                return new ReceiverWebApp.Controllers.StatusController(_msmqReceiverService);
            }
            return null;
        }

        public System.Collections.Generic.IEnumerable<object> GetServices(Type serviceType)
        {
            return new object[0];
        }

        public System.Web.Http.Dependencies.IDependencyScope BeginScope()
        {
            return this;
        }

        public void Dispose()
        {
        }
    }
}

