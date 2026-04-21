// Copyright (c) Brock Allen & Dominick Baier. All rights reserved.
// Licensed under the Apache License, Version 2.0. See LICENSE in the project root for license information.

using IdentityServer4.Extensions;

namespace IdentityServer4.Logging
{
    internal static class SensitiveDataMasker
    {
        public static string MaskToken(string token)
        {
            return token.Obfuscate();
        }
    }
}
