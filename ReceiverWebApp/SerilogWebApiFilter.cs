using System;
using System.Diagnostics;
using System.Web.Http.Controllers;
using System.Web.Http.Filters;
using Serilog;
using Serilog.Context;

namespace ReceiverWebApp
{
    /// <summary>
    /// Web API action filter that enriches logs with HTTP request context
    /// </summary>
    public class SerilogWebApiFilter : ActionFilterAttribute
    {
        private const string StopwatchKey = "SerilogWebApi_Stopwatch";

        public override void OnActionExecuting(HttpActionContext actionContext)
        {
            var stopwatch = Stopwatch.StartNew();
            actionContext.Request.Properties[StopwatchKey] = stopwatch;

            var method = actionContext.Request.Method.Method;
            var path = actionContext.Request.RequestUri.PathAndQuery;
            var controller = actionContext.ControllerContext.ControllerDescriptor.ControllerName;
            var action = actionContext.ActionDescriptor.ActionName;

            // Push HTTP context properties into Serilog LogContext
            LogContext.PushProperty("HttpMethod", method);
            LogContext.PushProperty("HttpPath", path);
            LogContext.PushProperty("Controller", controller);
            LogContext.PushProperty("Action", action);
            LogContext.PushProperty("RequestId", Guid.NewGuid().ToString());

            Log.Information("HTTP {HttpMethod} {HttpPath} started", method, path);

            base.OnActionExecuting(actionContext);
        }

        public override void OnActionExecuted(HttpActionExecutedContext actionExecutedContext)
        {
            base.OnActionExecuted(actionExecutedContext);

            var method = actionExecutedContext.Request.Method.Method;
            var path = actionExecutedContext.Request.RequestUri.PathAndQuery;
            
            var stopwatch = actionExecutedContext.Request.Properties.ContainsKey(StopwatchKey)
                ? actionExecutedContext.Request.Properties[StopwatchKey] as Stopwatch
                : null;

            var elapsed = stopwatch?.ElapsedMilliseconds ?? 0;

            var statusCode = actionExecutedContext.Response?.StatusCode ?? System.Net.HttpStatusCode.InternalServerError;

            if (actionExecutedContext.Exception != null)
            {
                Log.Error(actionExecutedContext.Exception, 
                    "HTTP {HttpMethod} {HttpPath} failed with {StatusCode} in {ElapsedMs}ms",
                    method, path, (int)statusCode, elapsed);
            }
            else
            {
                Log.Information(
                    "HTTP {HttpMethod} {HttpPath} completed with {StatusCode} in {ElapsedMs}ms",
                    method, path, (int)statusCode, elapsed);
            }

            stopwatch?.Stop();
        }
    }
}

