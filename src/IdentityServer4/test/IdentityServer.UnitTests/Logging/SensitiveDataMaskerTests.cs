// Copyright (c) Brock Allen & Dominick Baier. All rights reserved.
// Licensed under the Apache License, Version 2.0. See LICENSE in the project root for license information.

using IdentityServer4.Logging;
using Xunit;

namespace IdentityServer.UnitTests.Logging
{
    public class SensitiveDataMaskerTests
    {
        [Theory]
        [InlineData(null)]
        [InlineData("")]
        [InlineData("abc")]
        [InlineData("abcd")]
        public void MaskToken_ShouldMaskShortOrMissingValues(string token)
        {
            var masked = SensitiveDataMasker.MaskToken(token);

            Assert.Equal("********", masked);
        }

        [Fact]
        public void MaskToken_ShouldKeepOnlyLast4Chars()
        {
            var masked = SensitiveDataMasker.MaskToken("abcdefghijklmnop");

            Assert.Equal("****mnop", masked);
        }
    }
}
