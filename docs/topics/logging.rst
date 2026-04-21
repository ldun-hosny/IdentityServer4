
Logging
=======
IdentityServer uses the standard logging facilities provided by ASP.NET Core.
The Microsoft `documentation <https://docs.microsoft.com/en-us/aspnet/core/fundamentals/logging>`_ has a good intro and a description of the built-in logging providers.

We are roughly following the Microsoft guidelines for usage of log levels:

* ``Trace`` For information that is valuable only to a developer troubleshooting an issue. Token values at this level are **masked** (only the last 4 characters are shown) to reduce accidental credential exposure. Do not enable Trace in production log aggregation pipelines.
* ``Debug`` For following the internal flow and understanding why certain decisions are made. Has short-term usefulness during development and debugging.
* ``Information`` For tracking the general flow of the application. These logs typically have some long-term value.
* ``Warning`` For abnormal or unexpected events in the application flow. These may include errors or other conditions that do not cause the application to stop, but which may need to be investigated.
* ``Error`` For errors and exceptions that cannot be handled. Examples: failed validation of a protocol request.
* ``Critical`` For failures that require immediate attention. Examples: missing store implementation, invalid key material...

Token Masking
^^^^^^^^^^^^^
All token values (access tokens, refresh tokens, identity tokens, authorization codes, device codes, and user codes) that appear in ``Trace``-level log messages are masked using ``****<last4chars>`` format. This prevents accidental exposure in log aggregation systems such as Elasticsearch, Datadog, or Azure Monitor.

Raw token values are **never** logged above ``Trace`` level.

If you are implementing custom logging or events that include token values, apply the same pattern::

    // Safe — mask before logging
    _logger.LogTrace("Token: {token}", SensitiveDataMasker.MaskToken(token));

StrictJarValidation Warnings
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
When ``StrictJarValidation`` is disabled (the default), IdentityServer logs ``Warning``-level messages when clients send JWT authorization request objects (JAR / RFC 9101) with a ``typ`` header or ``content-type`` that would be rejected under strict mode.

Monitor these warnings and update non-conforming clients before enabling ``StrictJarValidation = true``::

    services.AddIdentityServer(options =>
    {
        // Enable after all clients have been verified
        options.StrictJarValidation = true;
    });

Setup for Serilog
^^^^^^^^^^^^^^^^^
We personally like `Serilog <https://serilog.net/>`_ and the ``Serilog.AspNetCore`` package a lot. Give it a try::

    public class Program
    {
        public static int Main(string[] args)
        {
            Activity.DefaultIdFormat = ActivityIdFormat.W3C;

            Log.Logger = new LoggerConfiguration()
                .MinimumLevel.Debug()
                .MinimumLevel.Override("Microsoft", LogEventLevel.Warning)
                .MinimumLevel.Override("Microsoft.Hosting.Lifetime", LogEventLevel.Information)
                .MinimumLevel.Override("System", LogEventLevel.Warning)
                .MinimumLevel.Override("Microsoft.AspNetCore.Authentication", LogEventLevel.Information)
                .Enrich.FromLogContext()
                .WriteTo.Console(outputTemplate: "[{Timestamp:HH:mm:ss} {Level}] {SourceContext}{NewLine}{Message:lj}{NewLine}{Exception}{NewLine}", theme: AnsiConsoleTheme.Code)
                .CreateLogger();

            try
            {
                Log.Information("Starting host...");
                CreateHostBuilder(args).Build().Run();
                return 0;
            }
            catch (Exception ex)
            {
                Log.Fatal(ex, "Host terminated unexpectedly.");
                return 1;
            }
            finally
            {
                Log.CloseAndFlush();
            }
        }

        public static IHostBuilder CreateHostBuilder(string[] args) =>
            Microsoft.Extensions.Hosting.Host.CreateDefaultBuilder(args)
                .UseSerilog()
                .ConfigureWebHostDefaults(webBuilder =>
                {
                    webBuilder.UseStartup<Startup>();
                });
    }