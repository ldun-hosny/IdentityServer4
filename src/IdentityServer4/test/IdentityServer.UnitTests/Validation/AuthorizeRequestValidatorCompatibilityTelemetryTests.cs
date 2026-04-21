// Copyright (c) Brock Allen & Dominick Baier. All rights reserved.
// Licensed under the Apache License, Version 2.0. See LICENSE in the project root for license information.


using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Threading.Tasks;
using FluentAssertions;
using IdentityModel;
using IdentityServer.UnitTests.Common;
using IdentityServer.UnitTests.Validation.Setup;
using IdentityServer4.Configuration;
using IdentityServer4.Models;
using IdentityServer4.Services;
using IdentityServer4.Validation;
using Microsoft.Extensions.Logging;
using Xunit;

namespace IdentityServer.UnitTests.Validation
{
    public class AuthorizeRequestValidatorCompatibilityTelemetryTests
    {
        private const string Category = "AuthorizeRequestValidator Compatibility Telemetry";

        [Fact]
        [Trait("Category", Category)]
        public async Task http_request_uri_should_emit_warning()
        {
            var loggerProvider = new CollectingLoggerProvider();
            var loggerFactory = new LoggerFactory(new[] { loggerProvider });

            var validator = CreateAuthorizeRequestValidator(
                loggerFactory.CreateLogger<AuthorizeRequestValidator>(),
                new StubJwtRequestUriHttpClient("jwt"),
                new StubJwtRequestValidator());

            var parameters = new NameValueCollection
            {
                { OidcConstants.AuthorizeRequest.ClientId, "codeclient" },
                { OidcConstants.AuthorizeRequest.Scope, "openid" },
                { OidcConstants.AuthorizeRequest.RedirectUri, "https://server/cb" },
                { OidcConstants.AuthorizeRequest.ResponseType, OidcConstants.ResponseTypes.Code },
                { OidcConstants.AuthorizeRequest.RequestUri, "http://client_jwt" }
            };

            var result = await validator.ValidateAsync(parameters);

            result.IsError.Should().BeFalse();
            loggerProvider.Messages.Should().Contain(m =>
                m.Level == LogLevel.Warning &&
                m.Message.Contains("request_uri") &&
                m.Message.Contains("http") &&
                m.Message.Contains("codeclient"));
        }

        [Fact]
        [Trait("Category", Category)]
        public async Task https_request_uri_should_not_emit_warning()
        {
            var loggerProvider = new CollectingLoggerProvider();
            var loggerFactory = new LoggerFactory(new[] { loggerProvider });

            var validator = CreateAuthorizeRequestValidator(
                loggerFactory.CreateLogger<AuthorizeRequestValidator>(),
                new StubJwtRequestUriHttpClient("jwt"),
                new StubJwtRequestValidator());

            var parameters = new NameValueCollection
            {
                { OidcConstants.AuthorizeRequest.ClientId, "codeclient" },
                { OidcConstants.AuthorizeRequest.Scope, "openid" },
                { OidcConstants.AuthorizeRequest.RedirectUri, "https://server/cb" },
                { OidcConstants.AuthorizeRequest.ResponseType, OidcConstants.ResponseTypes.Code },
                { OidcConstants.AuthorizeRequest.RequestUri, "https://client_jwt" }
            };

            var result = await validator.ValidateAsync(parameters);

            result.IsError.Should().BeFalse();
            loggerProvider.Messages.Should().NotContain(m =>
                m.Level == LogLevel.Warning &&
                m.Message.Contains("request_uri") &&
                m.Message.Contains("http"));
        }

        private static AuthorizeRequestValidator CreateAuthorizeRequestValidator(
            ILogger<AuthorizeRequestValidator> logger,
            IJwtRequestUriHttpClient jwtRequestUriHttpClient,
            JwtRequestValidator jwtRequestValidator)
        {
            var options = TestIdentityServerOptions.Create();
            options.Endpoints.EnableJwtRequestUri = true;

            return new AuthorizeRequestValidator(
                options,
                Factory.CreateClientStore(),
                new DefaultCustomAuthorizeRequestValidator(),
                new StrictRedirectUriValidator(),
                Factory.CreateResourceValidator(),
                new MockUserSession(),
                jwtRequestValidator,
                jwtRequestUriHttpClient,
                logger);
        }

        private class StubJwtRequestUriHttpClient : IJwtRequestUriHttpClient
        {
            private readonly string _value;

            public StubJwtRequestUriHttpClient(string value)
            {
                _value = value;
            }

            public Task<string> GetJwtAsync(string url, Client client)
            {
                return Task.FromResult(_value);
            }
        }

        private class StubJwtRequestValidator : JwtRequestValidator
        {
            public StubJwtRequestValidator() : base("https://identityserver", new LoggerFactory().CreateLogger<JwtRequestValidator>())
            {
            }

            public override Task<JwtRequestValidationResult> ValidateAsync(Client client, string jwtTokenString)
            {
                return Task.FromResult(new JwtRequestValidationResult
                {
                    IsError = false,
                    Payload = new Dictionary<string, string>
                    {
                        { OidcConstants.AuthorizeRequest.ClientId, client.ClientId }
                    }
                });
            }
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
