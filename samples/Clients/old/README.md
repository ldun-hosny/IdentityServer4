# Deprecated Samples

The samples in this directory use the **implicit flow** and **hybrid flow**, both of which are
**deprecated** by [OAuth 2.0 Security Best Current Practice (RFC 9700)](https://datatracker.ietf.org/doc/html/rfc9700)
and the [OAuth 2.1 draft specification](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1).

They are kept here for historical reference only and are **not maintained**.

## Recommended replacements

| Deprecated sample | Replace with |
|---|---|
| `MvcHybrid` | `samples/Clients/src/MvcCode` (Authorization Code + PKCE) |
| `MvcHybridAutomaticRefresh` | `samples/Clients/src/MvcAutomaticTokenManagement` |
| `MvcImplicit` | `samples/Clients/src/MvcCode` |
| `MvcImplicitJwtRequest` | `samples/Clients/src/MvcCode` with `request` parameter |
| `MvcManual` | `samples/Clients/src/MvcCode` |

For new integrations, use the [Authorization Code flow with PKCE](https://identityserver4.readthedocs.io/en/latest/topics/grant_types.html).
