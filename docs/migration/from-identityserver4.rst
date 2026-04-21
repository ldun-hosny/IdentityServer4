Migrate from IdentityServer4 Packages to Ldun Fork
==================================================

This guide explains how to move an existing solution from upstream ``IdentityServer4.*`` NuGet packages to the ldun-maintained fork packages.

Scope
^^^^^

- Migrate package IDs only (namespace usage in code typically remains ``IdentityServer4``).
- Move to the ldun .NET 8-compatible package line.
- Validate runtime behavior before production rollout.

Package Mapping
^^^^^^^^^^^^^^^

.. list-table::
   :header-rows: 1

   * - Upstream package
     - Ldun fork package
   * - ``IdentityServer4``
     - ``Ldun.IdentityServer4``
   * - ``IdentityServer4.Storage``
     - ``Ldun.IdentityServer4.Storage``
   * - ``IdentityServer4.AspNetIdentity``
     - ``Ldun.IdentityServer4.AspNetIdentity``
   * - ``IdentityServer4.EntityFramework.Storage``
     - ``Ldun.IdentityServer4.EntityFramework.Storage``
   * - ``IdentityServer4.EntityFramework``
     - ``Ldun.IdentityServer4.EntityFramework``

Prerequisites
^^^^^^^^^^^^^

- .NET 8 SDK installed.
- Existing application and tests building before migration.
- A dedicated migration branch.

Migration Steps
^^^^^^^^^^^^^^^

1. Update package references in your ``.csproj`` files.

   Example::

      <PackageReference Include="Ldun.IdentityServer4" Version="5.0.0" />
      <PackageReference Include="Ldun.IdentityServer4.AspNetIdentity" Version="5.0.0" />

2. Restore and rebuild:

   .. code-block:: bash

      dotnet restore
      dotnet build -c Release

3. Run automated tests:

   .. code-block:: bash

      dotnet test -c Release

4. Run benchmark gates (recommended before release):

   .. code-block:: bash

      ./benchmark/run.sh

   Strict gate profile:

   .. code-block:: bash

      BENCH_PROFILE=ci ./benchmark/run.sh

5. Run a runtime smoke test against your host:

   - Discovery endpoint returns metadata.
   - Token endpoint returns valid access tokens for expected clients/scopes.
   - Existing API resource validation still succeeds.

Runtime Safety Checklist
^^^^^^^^^^^^^^^^^^^^^^^^

- Signing credentials/certificates are available in deployment environment.
- Discovery document is reachable.
- ``client_credentials`` and interactive flows succeed for representative clients.
- Downstream APIs accept new tokens as expected.
- No sensitive data is emitted in logs.

Publish and Consumption
^^^^^^^^^^^^^^^^^^^^^^^

Use the repository publish script to enforce restore, tests, optional benchmark gates, pack, and push:

.. code-block:: bash

   bash publish-nuget.sh

When prompted:

- Choose benchmark profile ``local`` for workstation validation.
- Choose benchmark profile ``ci`` for strict release validation.

.. note::
   For globally consumed packages, keep project dependencies as ``PackageReference`` in released ``.csproj`` files (not local ``ProjectReference`` paths).

