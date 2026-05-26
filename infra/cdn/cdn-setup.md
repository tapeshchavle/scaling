# Azure CDN / Front Door Setup Guide

> **Note:** Azure CDN Classic (Standard Microsoft, Standard Verizon, Premium Verizon, Standard Akamai) has been announced as End of Life (EOL) with retirement scheduled for September 30, 2027. All new deployments should use **Azure Front Door Standard/Premium**, which replaces Azure CDN Classic and provides an integrated CDN + WAF + global load balancing solution.

---

## 1. Architecture Overview

```
Users → Azure Front Door (Global Edge PoPs)
         ├── Static Assets (cached 24h)
         ├── API GET responses (cached 60s)
         └── Origin: Nginx Gateway (Azure Container Apps / AKS)
```

Azure Front Door acts as the global entry point, providing:
- **CDN caching** at 100+ edge locations worldwide
- **WAF (Web Application Firewall)** with managed OWASP rulesets
- **SSL/TLS termination** with managed certificates
- **Global load balancing** with health probes
- **Compression** (gzip + Brotli)

---

## 2. Azure Front Door Standard/Premium Setup

### 2.1 Create Front Door Profile

```bash
# Create resource group (if not exists)
az group create \
  --name rg-food-app-prod \
  --location eastus

# Create Front Door profile (Premium tier for WAF support)
az afd profile create \
  --profile-name fd-food-app-prod \
  --resource-group rg-food-app-prod \
  --sku Premium_AzureFrontDoor
```

### 2.2 Create Endpoint

```bash
az afd endpoint create \
  --endpoint-name food-app \
  --profile-name fd-food-app-prod \
  --resource-group rg-food-app-prod \
  --enabled-state Enabled
```

This creates the endpoint: `food-app.<hash>.z01.azurefd.net`

---

## 3. Origin Group Configuration

### 3.1 Create Origin Group

```bash
az afd origin-group create \
  --origin-group-name og-nginx-gateway \
  --profile-name fd-food-app-prod \
  --resource-group rg-food-app-prod \
  --probe-request-type GET \
  --probe-protocol Http \
  --probe-path "/health" \
  --probe-interval-in-seconds 30 \
  --sample-size 4 \
  --successful-samples-required 3 \
  --additional-latency-in-milliseconds 50
```

### 3.2 Add Origins

```bash
# Primary origin (Nginx on Azure Container Apps)
az afd origin create \
  --origin-name nginx-primary \
  --origin-group-name og-nginx-gateway \
  --profile-name fd-food-app-prod \
  --resource-group rg-food-app-prod \
  --host-name food-app-gateway.azurecontainerapps.io \
  --origin-host-header food-app-gateway.azurecontainerapps.io \
  --http-port 80 \
  --https-port 443 \
  --priority 1 \
  --weight 1000 \
  --enabled-state Enabled

# Secondary origin (failover region)
az afd origin create \
  --origin-name nginx-secondary \
  --origin-group-name og-nginx-gateway \
  --profile-name fd-food-app-prod \
  --resource-group rg-food-app-prod \
  --host-name food-app-gateway-westus.azurecontainerapps.io \
  --origin-host-header food-app-gateway-westus.azurecontainerapps.io \
  --http-port 80 \
  --https-port 443 \
  --priority 2 \
  --weight 1000 \
  --enabled-state Enabled
```

---

## 4. Caching Rules

### 4.1 Rule Set for Caching Policies

```bash
# Create rule set
az afd rule-set create \
  --rule-set-name CachingRules \
  --profile-name fd-food-app-prod \
  --resource-group rg-food-app-prod
```

### 4.2 Static Assets Rule (24h TTL)

Matches: `*.js`, `*.css`, `*.png`, `*.jpg`, `*.jpeg`, `*.gif`, `*.svg`, `*.woff2`, `*.ico`

```bash
az afd rule create \
  --rule-name StaticAssetsCaching \
  --rule-set-name CachingRules \
  --profile-name fd-food-app-prod \
  --resource-group rg-food-app-prod \
  --order 1 \
  --match-variable RequestFilenameExtension \
  --operator Contains \
  --match-values js css png jpg jpeg gif svg woff2 ico \
  --action-name CacheExpiration \
  --cache-behavior Override \
  --cache-duration "1.00:00:00"
```

### 4.3 API GET Responses Rule (60s TTL)

Matches: `/api/v1/food/*` with `GET` method only.

```bash
az afd rule create \
  --rule-name ApiGetCaching \
  --rule-set-name CachingRules \
  --profile-name fd-food-app-prod \
  --resource-group rg-food-app-prod \
  --order 2 \
  --match-variable RequestUri \
  --operator Contains \
  --match-values "/api/v1/food/" \
  --action-name CacheExpiration \
  --cache-behavior Override \
  --cache-duration "0.00:01:00"
```

> **Important:** Ensure that only `GET` requests are cached. POST/PUT/DELETE must always reach the origin. Configure the route to use query string caching with `IncludeSpecifiedQueryStrings` for relevant parameters.

### 4.4 No-Cache Rule for Notifications

```bash
az afd rule create \
  --rule-name NotificationNoCache \
  --rule-set-name CachingRules \
  --profile-name fd-food-app-prod \
  --resource-group rg-food-app-prod \
  --order 3 \
  --match-variable RequestUri \
  --operator Contains \
  --match-values "/api/v1/notifications/" \
  --action-name CacheExpiration \
  --cache-behavior BypassCache
```

---

## 5. Routes

```bash
# Main route with caching rule set
az afd route create \
  --route-name default-route \
  --endpoint-name food-app \
  --profile-name fd-food-app-prod \
  --resource-group rg-food-app-prod \
  --origin-group og-nginx-gateway \
  --supported-protocols Https Http \
  --https-redirect Enabled \
  --patterns-to-match "/*" \
  --forwarding-protocol HttpOnly \
  --rule-sets CachingRules \
  --query-string-caching-behavior IncludeSpecifiedQueryStrings \
  --link-to-default-domain Enabled
```

---

## 6. WAF Configuration (OWASP Managed Rules)

### 6.1 Create WAF Policy

```bash
az network front-door waf-policy create \
  --name wafFoodAppProd \
  --resource-group rg-food-app-prod \
  --sku Premium_AzureFrontDoor \
  --mode Prevention
```

### 6.2 Add OWASP Managed Ruleset

```bash
az network front-door waf-policy managed-rules add \
  --policy-name wafFoodAppProd \
  --resource-group rg-food-app-prod \
  --type Microsoft_DefaultRuleSet \
  --version 2.1 \
  --action Block
```

### 6.3 Add Bot Protection

```bash
az network front-door waf-policy managed-rules add \
  --policy-name wafFoodAppProd \
  --resource-group rg-food-app-prod \
  --type Microsoft_BotManagerRuleSet \
  --version 1.0 \
  --action Block
```

### 6.4 Rate Limiting Rule

```bash
az network front-door waf-policy rule create \
  --policy-name wafFoodAppProd \
  --resource-group rg-food-app-prod \
  --name RateLimitApiRequests \
  --priority 100 \
  --rule-type RateLimitRule \
  --rate-limit-threshold 1000 \
  --rate-limit-duration-in-minutes 1 \
  --action Block \
  --match-variable RequestUri \
  --operator Contains \
  --values "/api/"
```

### 6.5 Associate WAF with Front Door

```bash
az afd security-policy create \
  --security-policy-name sp-waf-food-app \
  --profile-name fd-food-app-prod \
  --resource-group rg-food-app-prod \
  --waf-policy /subscriptions/{subscription-id}/resourceGroups/rg-food-app-prod/providers/Microsoft.Network/FrontDoorWebApplicationFirewallPolicies/wafFoodAppProd \
  --domains /subscriptions/{subscription-id}/resourceGroups/rg-food-app-prod/providers/Microsoft.Cdn/profiles/fd-food-app-prod/afdEndpoints/food-app
```

---

## 7. Custom Domain + Managed TLS

### 7.1 Add Custom Domain

```bash
az afd custom-domain create \
  --custom-domain-name food-app-domain \
  --profile-name fd-food-app-prod \
  --resource-group rg-food-app-prod \
  --host-name api.foodapp.com \
  --certificate-type ManagedCertificate \
  --minimum-tls-version TLS12
```

### 7.2 DNS Configuration

Add a CNAME record for domain validation:

| Type  | Name           | Value                                    | TTL  |
|-------|----------------|------------------------------------------|------|
| CNAME | api            | food-app.\<hash\>.z01.azurefd.net        | 3600 |
| TXT   | _dnsauth.api   | \<validation-token\>                     | 3600 |

### 7.3 Associate Domain with Route

```bash
az afd route update \
  --route-name default-route \
  --endpoint-name food-app \
  --profile-name fd-food-app-prod \
  --resource-group rg-food-app-prod \
  --custom-domains food-app-domain
```

---

## 8. Origin Protection via `X-Azure-FDID` Header

To ensure the origin (Nginx gateway) only accepts traffic from Azure Front Door, validate the `X-Azure-FDID` header at the origin.

### 8.1 Get Front Door ID

```bash
az afd profile show \
  --profile-name fd-food-app-prod \
  --resource-group rg-food-app-prod \
  --query frontDoorId -o tsv
```

### 8.2 Nginx Origin Validation

Add to Nginx `default.conf` (inside the `server` block):

```nginx
# Reject requests not coming from Azure Front Door
set $valid_front_door 0;
if ($http_x_azure_fdid = "<YOUR-FRONT-DOOR-ID>") {
    set $valid_front_door 1;
}
# Uncomment in production:
# if ($valid_front_door = 0) {
#     return 403;
# }
```

### 8.3 Azure Container Apps IP Restriction (Alternative)

```bash
az containerapp ingress access-restriction set \
  --name food-app-gateway \
  --resource-group rg-food-app-prod \
  --rule-name AllowFrontDoor \
  --ip-address AzureFrontDoor.Backend \
  --action Allow
```

---

## 9. Compression

Azure Front Door supports both **gzip** and **Brotli** compression at the edge. Enable compression on the route:

```bash
az afd route update \
  --route-name default-route \
  --endpoint-name food-app \
  --profile-name fd-food-app-prod \
  --resource-group rg-food-app-prod \
  --enable-compression true
```

Compressed content types (automatic):
- `text/html`, `text/css`, `text/javascript`
- `application/json`, `application/javascript`
- `application/xml`, `text/xml`
- `image/svg+xml`

> **Note:** Compression is applied at the edge PoP, not at the origin. The Nginx gateway also compresses via `gzip`, so responses may arrive pre-compressed. Front Door will serve the compressed version directly if the `Accept-Encoding` matches.

---

## 10. Cache Purge

### 10.1 Purge Specific Paths

```bash
# Purge all food API cache
az afd endpoint purge \
  --endpoint-name food-app \
  --profile-name fd-food-app-prod \
  --resource-group rg-food-app-prod \
  --content-paths "/api/v1/food/*"

# Purge all cached content
az afd endpoint purge \
  --endpoint-name food-app \
  --profile-name fd-food-app-prod \
  --resource-group rg-food-app-prod \
  --content-paths "/*"
```

### 10.2 Programmatic Purge (CI/CD Integration)

```bash
# Use in GitHub Actions / Azure DevOps pipeline after deployment
az afd endpoint purge \
  --endpoint-name food-app \
  --profile-name fd-food-app-prod \
  --resource-group rg-food-app-prod \
  --content-paths "/api/v1/food/*" "/static/*"
```

---

## 11. Monitoring & Diagnostics

### 11.1 Enable Diagnostic Logs

```bash
az monitor diagnostic-settings create \
  --name fd-diagnostics \
  --resource /subscriptions/{sub-id}/resourceGroups/rg-food-app-prod/providers/Microsoft.Cdn/profiles/fd-food-app-prod \
  --logs '[{"category":"FrontDoorAccessLog","enabled":true},{"category":"FrontDoorHealthProbeLog","enabled":true},{"category":"FrontDoorWebApplicationFirewallLog","enabled":true}]' \
  --workspace /subscriptions/{sub-id}/resourceGroups/rg-food-app-prod/providers/Microsoft.OperationalInsights/workspaces/law-food-app-prod
```

### 11.2 Key Metrics to Monitor

| Metric                    | Alert Threshold       | Description                        |
|---------------------------|-----------------------|------------------------------------|
| Origin Latency            | > 500ms (P95)        | Time to first byte from origin     |
| Cache Hit Ratio           | < 80%                | Percentage of requests served from cache |
| 4xx Error Rate            | > 5%                 | Client-side errors                 |
| 5xx Error Rate            | > 1%                 | Server-side errors                 |
| WAF Blocked Requests      | > 100/min            | Potential attack indicator         |
| Total Requests            | Baseline + 200%      | Traffic spike detection            |

---

## Summary

| Component         | Configuration                              |
|-------------------|--------------------------------------------|
| **CDN Tier**      | Azure Front Door Premium                   |
| **WAF**           | OWASP 2.1 + Bot Protection (Prevention)    |
| **TLS**           | Managed certificate, TLS 1.2 minimum       |
| **Static Cache**  | 24 hours TTL                               |
| **API Cache**     | 60 seconds TTL (GET only)                  |
| **Compression**   | gzip + Brotli at edge                      |
| **Origin Protection** | X-Azure-FDID header validation          |
| **Monitoring**    | Access logs, health probes, WAF logs       |
