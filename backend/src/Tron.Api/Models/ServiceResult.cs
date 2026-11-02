using Microsoft.AspNetCore.Mvc;

namespace Tron.Api.Models;

public class ServiceResult
{
    public bool IsSuccess { get; init; }
    public string? ErrorCode { get; init; }
    public string? ErrorMessage { get; init; }
    public int StatusCode { get; init; }

    public static ServiceResult Success(int statusCode = 200) =>
        new() { IsSuccess = true, StatusCode = statusCode };

    public static ServiceResult Failed(string errorCode, string message, int statusCode = 400) =>
        new() { IsSuccess = false, ErrorCode = errorCode, ErrorMessage = message, StatusCode = statusCode };
}

public class ServiceResult<T>
{
    public bool IsSuccess { get; init; }
    public T? Data { get; init; }
    public string? ErrorCode { get; init; }
    public string? ErrorMessage { get; init; }
    public int StatusCode { get; init; }

    public static ServiceResult<T> Success(T data, int statusCode = 200) =>
        new() { IsSuccess = true, Data = data, StatusCode = statusCode };

    public static ServiceResult<T> Failed(string errorCode, string message, int statusCode = 400) =>
        new() { IsSuccess = false, ErrorCode = errorCode, ErrorMessage = message, StatusCode = statusCode };
}

public static class ControllerResultExtensions
{
    public static ActionResult ToActionResult<T>(this ControllerBase controller, ServiceResult<T> result)
    {
        if (result.IsSuccess)
        {
            return controller.StatusCode(result.StatusCode, result.Data);
        }
        var problem = new ProblemDetails
        {
            Status = result.StatusCode,
            Title = result.ErrorCode,
            Detail = result.ErrorMessage,
            Instance = controller.HttpContext.Request.Path
        };
        problem.Extensions["errorCode"] = result.ErrorCode;
        return controller.StatusCode(result.StatusCode, problem);
    }

    public static IActionResult ToActionResult(this ControllerBase controller, ServiceResult result)
    {
        if (result.IsSuccess)
        {
            return controller.NoContent();
        }
        var problem = new ProblemDetails
        {
            Status = result.StatusCode,
            Title = result.ErrorCode,
            Detail = result.ErrorMessage,
            Instance = controller.HttpContext.Request.Path
        };
        problem.Extensions["errorCode"] = result.ErrorCode;
        return controller.StatusCode(result.StatusCode, problem);
    }
}
