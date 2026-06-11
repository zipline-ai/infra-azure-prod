-- @requires: DATABRICKS_HOST DATABRICKS_CLIENT_ID DATABRICKS_CLIENT_SECRET DATABRICKS_WAREHOUSE AZURE_STORAGE_ACCOUNT_NAME AZURE_TENANT_ID AZURE_CLIENT_ID AZURE_CLIENT_SECRET
--
-- Register Databricks Unity Catalog (Iceberg REST) with ADLS Gen2 storage.
-- StarRocks reads metadata from UC and Parquet from ADLS directly.
--
-- After registration, query with:
--   SET CATALOG databricks_unity;
--   USE data;
--   SELECT * FROM azure_demo_v1__1 LIMIT 10;
-- Drop + recreate so re-running starrocks-init always picks up the latest
-- env values (e.g. rotated Databricks client secret, Azure SP rotation).
-- External catalogs are metadata-only — no underlying data is touched.
DROP CATALOG IF EXISTS databricks_unity;
CREATE EXTERNAL CATALOG databricks_unity
PROPERTIES (
    "type" = "iceberg",
    "iceberg.catalog.type" = "rest",
    "iceberg.catalog.uri" = "${DATABRICKS_HOST}/api/2.1/unity-catalog/iceberg-rest",
    "security" = "OAUTH2",
    "oauth2.server-uri" = "${DATABRICKS_HOST}/oidc/v1/token",
    "oauth2.credential" = "${DATABRICKS_CLIENT_ID}:${DATABRICKS_CLIENT_SECRET}",
    "oauth2.scope" = "all-apis",
    "iceberg.catalog.warehouse" = "${DATABRICKS_WAREHOUSE}",
    "azure.adls2.storage_account" = "${AZURE_STORAGE_ACCOUNT_NAME}",
    "azure.adls2.oauth2_use_managed_identity" = "false",
    "azure.adls2.oauth2_tenant_id" = "${AZURE_TENANT_ID}",
    "azure.adls2.oauth2_client_id" = "${AZURE_CLIENT_ID}",
    "azure.adls2.oauth2_client_secret" = "${AZURE_CLIENT_SECRET}"
);
