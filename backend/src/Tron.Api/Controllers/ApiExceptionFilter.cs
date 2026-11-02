using System.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Serilog;
using Tron.Api.Models;

namespace Tron.Api.Controllers;

[DebuggerNonUserCode]
public class ApiExceptionFilter : IAsyncExceptionFilter
{
    public Task OnExceptionAsync(ExceptionContext context)
    {
        var statusCode = StatusCodes.Status500InternalServerError;
        var errorCode = "INTERNAL_ERROR";
        var message = "Đã xảy ra lỗi trên hệ thống. Vui lòng thử lại.";

        if (context.Exception is ApiDomainException domainEx)
        {
            statusCode = domainEx.StatusCode;
            errorCode = domainEx.ErrorCode;
            message = domainEx.Message;
        }
        else
        {
            Log.Error(context.Exception, "Unhandled exception on request {Method} {Path}",
                context.HttpContext.Request.Method,
                context.HttpContext.Request.Path);
        }

        var problem = new ProblemDetails
        {
            Status = statusCode,
            Title = errorCode,
            Detail = message,
            Instance = context.HttpContext.Request.Path
        };
        problem.Extensions["errorCode"] = errorCode;

        context.Result = new ObjectResult(problem) { StatusCode = statusCode };
        context.ExceptionHandled = true;
        return Task.CompletedTask;
    }
}
