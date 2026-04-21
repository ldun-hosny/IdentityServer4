// Copyright (c) Brock Allen & Dominick Baier. All rights reserved.
// Licensed under the Apache License, Version 2.0. See LICENSE in the project root for license information.


using System;
using IdentityServer4.Models;
using Microsoft.Extensions.Logging;
using System.Net.Http;
using System.Threading.Tasks;
using IdentityModel;
using IdentityServer4.Configuration;

namespace IdentityServer4.Services
{
    /// <summary>
    /// Default JwtRequest client
    /// </summary>
    public class DefaultJwtRequestUriHttpClient : IJwtRequestUriHttpClient
    {
        private readonly HttpClient _client;
        private readonly IdentityServerOptions _options;
        private readonly ILogger<DefaultJwtRequestUriHttpClient> _logger;

        /// <summary>
        /// ctor
        /// </summary>
        /// <param name="client">An HTTP client</param>
        /// <param name="options">The options.</param>
        /// <param name="loggerFactory">The logger factory</param>
        public DefaultJwtRequestUriHttpClient(HttpClient client, IdentityServerOptions options, ILoggerFactory loggerFactory)
        {
            _client = client;
            _options = options;
            _logger = loggerFactory.CreateLogger<DefaultJwtRequestUriHttpClient>();
        }


        /// <inheritdoc />
        public async Task<string> GetJwtAsync(string url, Client client)
        {
            var req = new HttpRequestMessage(HttpMethod.Get, url);
            req.Properties.Add(IdentityServerConstants.JwtRequestClientKey, client);

            var response = await _client.SendAsync(req);
            if (response.StatusCode == System.Net.HttpStatusCode.OK)
            {
                var mediaType = response.Content.Headers.ContentType?.MediaType;
                var expectedMediaType = $"application/{JwtClaimTypes.JwtTypes.AuthorizationRequest}";
                var validMediaType = string.Equals(mediaType, expectedMediaType, StringComparison.Ordinal);

                if (_options.StrictJarValidation)
                {
                    if (!validMediaType)
                    {
                        _logger.LogError("Invalid content type {type} from jwt url {url}", mediaType ?? "<missing>", url);
                        return null;
                    }
                }
                else if (!validMediaType)
                {
                    _logger.LogWarning(
                        "JWT request_uri response content type {type} from jwt url {url} for client {clientId} is accepted because StrictJarValidation is disabled, but would be rejected if StrictJarValidation is enabled.",
                        mediaType ?? "<missing>",
                        url,
                        client?.ClientId ?? "<unknown>");
                }

                _logger.LogDebug("Success http response from jwt url {url}", url);
                
                var json = await response.Content.ReadAsStringAsync();
                return json;
            }
                
            _logger.LogError("Invalid http status code {status} from jwt url {url}", response.StatusCode, url);
            return null;
        }
    }
}
