// Copyright (c) Brock Allen & Dominick Baier. All rights reserved.
// Licensed under the Apache License, Version 2.0. See LICENSE in the project root for license information.


using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IdentityModel.Tokens.Jwt;
using System.Threading.Tasks;
using FluentAssertions;
using IdentityModel;
using IdentityServer.UnitTests.Common;
using IdentityServer4.Configuration;
using IdentityServer4.Models;
using IdentityServer4.Validation;
using Microsoft.Extensions.Logging;
using Microsoft.IdentityModel.Tokens;
using Xunit;

namespace IdentityServer.UnitTests.Validation
{
    public class JwtRequestValidatorCompatibilityTelemetryTests
    {
        private const string Category = "JwtRequestValidator Compatibility Telemetry";

        [Fact]
        [Trait("Category", Category)]
        public async Task missing_jar_typ_should_emit_warning_when_strict_validation_disabled()
        {
            var loggerProvider = new CollectingLoggerProvider();
            var loggerFactory = new LoggerFactory(new[] { loggerProvider });

            var options = new IdentityServerOptions
            {
                StrictJarValidation = false
            };

            var token = new JwtSecurityToken(new JwtHeader(), new JwtPayload
            {
                { "client_id", "client" },
                { "scope", "openid" }
            });

            var sut = new TestableJwtRequestValidator(options, loggerFactory.CreateLogger<JwtRequestValidator>(), token);
            var client = new Client { ClientId = "client" };

            var result = await sut.ValidateAsync(client, "ignored");

            result.IsError.Should().BeFalse();
            loggerProvider.Messages.Should().Contain(m =>
                m.Level == LogLevel.Warning &&
                m.Message.Contains("StrictJarValidation") &&
                m.Message.Contains("client"));
        }

        [Fact]
        [Trait("Category", Category)]
        public async Task valid_jar_typ_should_not_emit_warning_when_strict_validation_disabled()
        {
            var loggerProvider = new CollectingLoggerProvider();
            var loggerFactory = new LoggerFactory(new[] { loggerProvider });

            var options = new IdentityServerOptions
            {
                StrictJarValidation = false
            };

            var header = new JwtHeader
            {
                { "typ", JwtClaimTypes.JwtTypes.AuthorizationRequest }
            };
            var token = new JwtSecurityToken(header, new JwtPayload
            {
                { "client_id", "client" },
                { "scope", "openid" }
            });

            var sut = new TestableJwtRequestValidator(options, loggerFactory.CreateLogger<JwtRequestValidator>(), token);
            var client = new Client { ClientId = "client" };

            var result = await sut.ValidateAsync(client, "ignored");

            result.IsError.Should().BeFalse();
            loggerProvider.Messages.Should().NotContain(m =>
                m.Level == LogLevel.Warning &&
                m.Message.Contains("StrictJarValidation"));
        }

        private class TestableJwtRequestValidator : JwtRequestValidator
        {
            private readonly JwtSecurityToken _token;

            public TestableJwtRequestValidator(IdentityServerOptions options, ILogger<JwtRequestValidator> logger, JwtSecurityToken token)
                : base(new MockHttpContextAccessor(options), options, logger)
            {
                _token = token;
            }

            protected override Task<List<SecurityKey>> GetKeysAsync(Client client)
            {
                return Task.FromResult(new List<SecurityKey>
                {
                    new SymmetricSecurityKey(new byte[32])
                });
            }

            protected override Task<JwtSecurityToken> ValidateJwtAsync(string jwtTokenString, IEnumerable<SecurityKey> keys, Client client)
            {
                return Task.FromResult(_token);
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
