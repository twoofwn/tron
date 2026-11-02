using System.Text;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Scalar.AspNetCore;
using Serilog;
using Tron.Api.Db;
using Tron.Api.Models;
using Tron.Api.Repositories;
using Tron.Api.Services;

var builder = WebApplication.CreateBuilder(args);

Log.Logger = new LoggerConfiguration()
    .ReadFrom.Configuration(builder.Configuration)
    .Enrich.FromLogContext()
    .WriteTo.Console()
    .CreateLogger();

builder.Host.UseSerilog();

builder.Services.Configure<JwtOptions>(builder.Configuration.GetSection(JwtOptions.SectionName));
builder.Services.Configure<StorageOptions>(builder.Configuration.GetSection(StorageOptions.SectionName));
builder.Services.Configure<DomainLimitOptions>(builder.Configuration.GetSection(DomainLimitOptions.SectionName));
builder.Services.Configure<RateLimitingOptions>(builder.Configuration.GetSection(RateLimitingOptions.SectionName));
builder.Services.Configure<CorsOptions>(builder.Configuration.GetSection(CorsOptions.SectionName));
builder.Services.Configure<CleanupOptions>(builder.Configuration.GetSection(CleanupOptions.SectionName));
builder.Services.Configure<DatabaseOptions>(builder.Configuration.GetSection(DatabaseOptions.SectionName));

// Sync static domain limits with appsettings
var domainLimitConfig = builder.Configuration.GetSection(DomainLimitOptions.SectionName).Get<DomainLimitOptions>();
if (domainLimitConfig != null)
{
    DomainLimits.Configure(domainLimitConfig);
}

var connectionString = builder.Configuration.GetConnectionString("Tron")
    ?? "Server=localhost;Database=TronDb;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=true";

builder.Services.AddDbContext<TronDbContext>(options =>
    options.UseSqlServer(connectionString));

// Repositories
builder.Services.AddScoped<UserRepository>();
builder.Services.AddScoped<CatalogRepository>();
builder.Services.AddScoped<MediaRepository>();
builder.Services.AddScoped<BackupRepository>();
builder.Services.AddScoped<ShareRepository>();
builder.Services.AddScoped<UserDataRepository>();
builder.Services.AddScoped<MarketRepository>();

// Services
builder.Services.AddSingleton<IMediaStorage, DiskMediaStorage>();
builder.Services.AddSingleton<IJwtTokenService, JwtTokenService>();
builder.Services.AddScoped<AuthService>();
builder.Services.AddScoped<CatalogAndMediaService>();
builder.Services.AddScoped<BackupAndShareService>();
builder.Services.AddScoped<UserDataService>();
builder.Services.AddScoped<MarketService>();
builder.Services.AddHostedService<StorageCleanupWorker>();

var jwtSection = builder.Configuration.GetSection(JwtOptions.SectionName).Get<JwtOptions>() ?? new JwtOptions();
var signingKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSection.SigningKey));

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = jwtSection.Issuer,
            ValidateAudience = true,
            ValidAudience = jwtSection.Audience,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = signingKey,
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromMinutes(Math.Max(0, jwtSection.ClockSkewMinutes))
        };
    });

builder.Services.AddAuthorization();

var rateLimitConfig = builder.Configuration.GetSection(RateLimitingOptions.SectionName).Get<RateLimitingOptions>() ?? new RateLimitingOptions();

builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddPolicy("auth", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: httpContext.Connection.RemoteIpAddress?.ToString() ?? "anon",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = rateLimitConfig.AuthPermitLimit,
                Window = TimeSpan.FromMinutes(Math.Max(1, rateLimitConfig.AuthWindowMinutes)),
                QueueLimit = 0
            }));

    options.AddPolicy("shares", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: httpContext.User.Identity?.Name ?? httpContext.Connection.RemoteIpAddress?.ToString() ?? "anon",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = rateLimitConfig.SharesPermitLimit,
                Window = TimeSpan.FromMinutes(Math.Max(1, rateLimitConfig.SharesWindowMinutes)),
                QueueLimit = 0
            }));
});

var corsConfig = builder.Configuration.GetSection(CorsOptions.SectionName).Get<CorsOptions>() ?? new CorsOptions();

builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        if (corsConfig.AllowedOrigins.Contains("*") || corsConfig.AllowedOrigins.Length == 0)
        {
            policy.AllowAnyOrigin()
                  .AllowAnyHeader()
                  .AllowAnyMethod();
        }
        else
        {
            policy.WithOrigins(corsConfig.AllowedOrigins)
                  .AllowAnyHeader()
                  .AllowAnyMethod()
                  .AllowCredentials();
        }
    });
});

builder.Services.AddControllers(options =>
{
    options.SuppressImplicitRequiredAttributeForNonNullableReferenceTypes = true;
    options.Filters.Add<Tron.Api.Controllers.ApiExceptionFilter>();
}).AddJsonOptions(options =>
{
    options.JsonSerializerOptions.Converters.Add(new FlexibleGuidJsonConverter());
});
builder.Services.AddOpenApi();
builder.Services.AddProblemDetails();

var app = builder.Build();

app.UseForwardedHeaders(new ForwardedHeadersOptions
{
    ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto
});

app.UseExceptionHandler(errApp =>
{
    errApp.Run(async context =>
    {
        var feature = context.Features.Get<IExceptionHandlerFeature>();
        var exception = feature?.Error;

        var statusCode = StatusCodes.Status500InternalServerError;
        var errorCode = "INTERNAL_ERROR";
        var message = "Đã xảy ra lỗi trên hệ thống. Vui lòng thử lại.";

        if (exception is ApiDomainException domainEx)
        {
            statusCode = domainEx.StatusCode;
            errorCode = domainEx.ErrorCode;
            message = domainEx.Message;
        }

        context.Response.StatusCode = statusCode;
        context.Response.ContentType = "application/problem+json";

        var problem = new ProblemDetails
        {
            Status = statusCode,
            Title = errorCode,
            Detail = message,
            Instance = context.Request.Path
        };
        problem.Extensions["errorCode"] = errorCode;

        await context.Response.WriteAsJsonAsync(problem);
    });
});

var enableDocs = app.Environment.IsDevelopment() || app.Configuration.GetValue("EnableApiDocumentation", true);
if (enableDocs)
{
    app.MapOpenApi();
    app.MapScalarApiReference();
}

app.UseCors();
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", () => Results.Ok(new
{
    service = "TRỐN (EscapeHatch) API",
    version = "1.0.0",
    status = "Online",
    docs = "/scalar/v1",
    health = "/api/v1/health",
    healthReady = "/api/v1/health/ready"
}));

app.MapControllers();

// Auto-initialize database schema and seed data via EF Core without any .sql files
if (app.Configuration.GetValue("Database:AutoInitialize", true))
{
    try
    {
        using var scope = app.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<TronDbContext>();
        await DbInitializer.InitializeAsync(db);
    }
    catch (Exception ex)
    {
        Serilog.Log.Warning(ex, "Database auto-initialization encountered an issue. Startup will continue.");
    }
}

app.Run();

public partial class Program;
