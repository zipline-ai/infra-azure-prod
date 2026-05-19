-- @requires: SNOWFLAKE_ACCOUNT SNOWFLAKE_CLIENT_ID SNOWFLAKE_CLIENT_SECRET POLARIS_WAREHOUSE POLARIS_PRINCIPAL_ROLE AZURE_STORAGE_ACCOUNT_NAME AZURE_TENANT_ID AZURE_CLIENT_ID AZURE_CLIENT_SECRET AZURE_STORAGE_ACCOUNT_KEY
--
-- Register Snowflake Open Catalog (Polaris, Iceberg REST) for ADLS Gen2
-- backed warehouses.
--
-- Two storage-auth blocks are configured:
--   1. `azure.adls2.*` (OAuth via service principal) — covers tables whose
--      Polaris-returned location uses `<account>.dfs.core.windows.net`.
--   2. `azure.blob.shared_key` — fallback for tables whose Polaris-returned
--      location uses `<account>.blob.core.windows.net`. Snowflake Open
--      Catalog currently registers locations with the blob hostname even
--      for ADLS Gen2 storage, and StarRocks's host-scoped OAuth properties
--      do NOT match `.blob.*` hosts. The shared key is the only auth that
--      reliably works for both `.dfs` and `.blob` paths today. Once the
--      Polaris catalog is re-registered with `.dfs.core.windows.net`
--      locations, this block can be removed and OAuth is sufficient.
--
-- Env-var naming mirrors `chronon/scripts/interactive/snowflake_session.py`
-- (Polaris bits) and `databricks-unity-azure.sql` (storage bits).
--
-- Drop + recreate so re-running starrocks-init always picks up the latest
-- env values (e.g. rotated client secret). External catalogs are
-- metadata-only — no underlying data is touched.
--
-- After registration, query with:
--   SET CATALOG snowflake_polaris;
--   USE demo;
--   SELECT * FROM azure_demo_v1__1 LIMIT 10;
DROP CATALOG IF EXISTS snowflake_polaris;
CREATE EXTERNAL CATALOG snowflake_polaris
PROPERTIES (
    "type" = "iceberg",
    "iceberg.catalog.type" = "rest",
    "iceberg.catalog.uri" = "https://${SNOWFLAKE_ACCOUNT}.snowflakecomputing.com/polaris/api/catalog",
    "iceberg.catalog.credential" = "${SNOWFLAKE_CLIENT_ID}:${SNOWFLAKE_CLIENT_SECRET}",
    "iceberg.catalog.scope" = "PRINCIPAL_ROLE:${POLARIS_PRINCIPAL_ROLE}",
    "iceberg.catalog.warehouse" = "${POLARIS_WAREHOUSE}",
    "iceberg.catalog.header.X-Iceberg-Access-Delegation" = "vended-credentials",
    "azure.adls2.storage_account" = "${AZURE_STORAGE_ACCOUNT_NAME}",
    "azure.adls2.oauth2_use_managed_identity" = "false",
    "azure.adls2.oauth2_tenant_id" = "${AZURE_TENANT_ID}",
    "azure.adls2.oauth2_client_id" = "${AZURE_CLIENT_ID}",
    "azure.adls2.oauth2_client_secret" = "${AZURE_CLIENT_SECRET}",
    "azure.blob.storage_account" = "${AZURE_STORAGE_ACCOUNT_NAME}",
    "azure.blob.shared_key" = "${AZURE_STORAGE_ACCOUNT_KEY}"
);