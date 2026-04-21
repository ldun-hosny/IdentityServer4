// Copyright (c) Brock Allen & Dominick Baier. All rights reserved.
// Licensed under the Apache License, Version 2.0. See LICENSE in the project root for license information.


using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Threading.Tasks;
using FluentAssertions;
using IdentityModel;
using IdentityServer.UnitTests.Common;
using IdentityServer4.Configuration;
using IdentityServer4.Models;
using IdentityServer4.Services;
using Microsoft.Extensions.Logging;
using Xunit;

namespace IdentityServer.UnitTests.Services.Default
{
    public class DefaultJwtRequestUriHttpClientCompatibilityTelemetryTests
    {
        private const string Category = "DefaultJwtRequestUriHttpClient Compatibility Telemetry";

        [Fact]
        [Trait("Category", Category)]
        public async Task invalid_content_type_should_emit_warning_when_strict_validation_disabled()
        {
            var loggerProvider = new CollectingLoggerProvider();
            var loggerFactory = new LoggerFactory(new[] { loggerProvider });
            var options = new IdentityServerOptions
            {
                StrictJarValidation = false
            };

            var handler = new NetworkHandler(_ =>
            {
                var response = new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = new StringContent("jwt-content")
                };
                response.Content.Headers.ContentType = new MediaTypeHeaderValue("text/plain");
                return response;
            });

            var sut = new DefaultJwtRequestUriHttpClient(new HttpClient(handler), options, loggerFactory);
            var client = new Client { ClientId = "client" };

            var result = await sut.GetJwtAsync("https://client_jwt", client);

            result.Should().Be("jwt-content");
            loggerProvider.Messages.Should().Contain(m =>
                m.Level == LogLevel.Warning &&
                m.Message.Contains("StrictJarValidation") &&
                m.Message.Contains("client"));
        }

        [Fact]
        [Trait("Category", Category)]
        public async Task valid_content_type_should_not_emit_warning_when_strict_validation_disabled()
        {
            var loggerProvider = new CollectingLoggerProvider();
            var loggerFactory = new LoggerFactory(new[] { loggerProvider });
            var options = new IdentityServerOptions
            {
                StrictJarValidation = false
            };

            var handler = new NetworkHandler(_ =>
            {
                var response = new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = new StringContent("jwt-content")
                };
                response.Content.Headers.ContentType =
                    new MediaTypeHeaderValue($"application/{JwtClaimTypes.JwtTypes.AuthorizationRequest}");
                return response;
            });

            var sut = new DefaultJwtRequestUriHttpClient(new HttpClient(handler), options, loggerFactory);
            var client = new Client { ClientId = "client" };

            var result = await sut.GetJwtAsync("https://client_jwt", client);

            result.Should().Be("jwt-content");
            loggerProvider.Messages.Should().NotContain(m =>
                m.Level == LogLevel.Warning &&
                m.Message.Contains("StrictJarValidation"));
        }

        private class CollectingLoggerProvider : ILoggerProvider
        {
            private readonly ConcurrentQueue<LogMessage> _messages = new ConcurrentQueue<LogMessage>();

            public IReadOnlyCollection<LogMessage> Messages => _messages.ToArray();

            public ILogger CreateLogger(string categoryName)
            {
                return new CollectingLogger(_messages);
            }

            public void Dispose()
            {
            }

            public class LogMessage
            {
                public LogLevel Level { get; set; }
                public string Message { get; set; }
            }

            private class CollectingLogger : ILogger
            {
                private readonly ConcurrentQueue<LogMessage> _messages;

                public CollectingLogger(ConcurrentQueue<LogMessage> messages)
                {
                    _messages = messages;
                }

                public IDisposable BeginScope<TState>(TState state)
                {
                    return NoopDisposable.Instance;
                }

                public bool IsEnabled(LogLevel logLevel)
                {
                    return true;
                }

                public void Log<TState>(
                    LogLevel logLevel,
                    EventId eventId,
                    TState state,
                    Exception exception,
                    Func<TState, Exception, string> formatter)
                {
                    _messages.Enqueue(new LogMessage
                    {
                        Level = logLevel,
                        Message = formatter(state, exception)
                    });
                }
            }
        }

        private class NoopDisposable : IDisposable
        {
            public static readonly NoopDisposable Instance = new NoopDisposable();

            public void Dispose()
            {
            }
        }
    }
}
