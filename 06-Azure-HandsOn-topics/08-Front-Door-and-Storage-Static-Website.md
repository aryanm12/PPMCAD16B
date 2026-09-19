# Lab 08 - Front Door Premium and a Private Storage Website Origin

**Read first:** [Brief notes - concepts for this lab](08-Front-Door-and-Storage-Static-Website-brief-notes.md)

**How to work:** Use Azure portal and your browser. Any website or sample text files are created in a local text editor; no command-line setup is required.

## Outcome

Publish a small HTTPS website through Azure Front Door, connect to its Storage origin with Private Link, disable direct public origin access and test cache invalidation.

**Time:** 60–100 minutes. **Costs:** Front Door **Premium** base/usage charges, Storage and network requests. Private Link to this origin requires Premium; Standard is not an interchangeable lower-cost selection for this lab.

## Prerequisites

- Contributor and permission to assign yourself Storage Blob Data Contributor.
- Access to [Azure portal](https://portal.azure.com) with your learning subscription selected. Keep a local worksheet of the resource names you choose.
- No custom domain is required. Use Front Door's generated HTTPS hostname.
- All website content is synthetic; the origin is briefly public during initial setup, then restricted.

## Lab 1 - Create storage and grant upload access

1. In [Azure portal](https://portal.azure.com), search **Resource groups → Create**. Select your learning subscription, name `azlab08-frontdoor`, Region **East US 2** (or the supported Region chosen for this lab). Select **Review + create → Create**.
2. Open the group → **Tags**; add `Project=AzureHandsOn` and `Lab=08`; **Apply**. Keep all resources below in this subscription, group and Region. Record names in your lab worksheet.

1. Search **Storage accounts → Create**. Select lab subscription/group/Region. Choose a globally unique name such as `azlab08yourinitials1234` (3–24 lowercase letters/digits); record your actual name. Performance **Standard**, redundancy **LRS**, general-purpose v2.
2. On **Advanced**, keep secure transfer required, minimum TLS **1.2**, and **Allow enabling anonymous access on individual containers** disabled. For this initial setup, **Networking → Public network access → Enable from all networks**. Private containers still require authorization.
3. **Review + create → Create**. Open **Overview** and verify deployment success. Use your recorded name wherever the guide says `YOUR-STORAGE-ACCOUNT`.

1. Open **your storage account → Access control (IAM) → Add → Add role assignment**.
2. Search/select **Storage Blob Data Contributor → Next**. Assign access to **User, group, or service principal**. **Select members** → your signed-in user. **Select → Review + assign** (confirm again if prompted).
3. Open **Role assignments** and verify role, member and scope. Allow several minutes for propagation. A Contributor role alone cannot assign roles; use an account with the required role-assignment permission.

1. Portal Storage account → **Data management → Static website → Enabled**.
2. Index document `index.html`; error document `error.html`. Save.
3. Record the **Primary endpoint** exactly, including its regional `web.core.windows.net` hostname.

Static website anonymous reads are not controlled by the blob-container public-access toggle in the same way as ordinary blob reads. Later we restrict the network endpoint and use Front Door Private Link.

## Lab 2 - Create and upload actual files

In the Azure portal:

Create a local folder `azlab08-site`. In a plain-text editor save these four files as UTF-8, Save As type **All files**, with no extra `.txt` extension:

**index.html**

```html
<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Azure website lab</title>
<link rel="stylesheet" href="/css/site.css"></head><body>
<h1>Front Door website - version 1</h1><p>Delivered over HTTPS.</p>
<a href="/about.html">About this lab</a></body></html>
```

**about.html**

```html
<!doctype html><html lang="en"><head><meta charset="utf-8"><title>About</title></head>
<body><h1>Storage + Front Door Premium + Private Link</h1><a href="/">Home</a></body></html>
```

**error.html**

```html
<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Not found</title></head>
<body><h1>404 - Page not found</h1><a href="/">Home</a></body></html>
```

**site.css**

```css
body{font-family:system-ui;max-width:800px;margin:4rem auto;color:#123;}
```

1. Portal **Storage account → Containers → $web**; select **Microsoft Entra user account** authentication. **Upload → Browse for files**, select the three HTML files and upload.
2. Upload `site.css` separately. Expand **Advanced** in Upload and set **Upload to folder** to `css`. Verify the resulting blob path is `css/site.css`.
3. Inspect blob **Properties**; Content-Type must be `text/html` for HTML and `text/css` for CSS. Correct/save if necessary.
4. Browse the website endpoint; verify the page, styling, About link and custom error page.

Wait for role propagation if authorization is initially denied. Open the Storage primary website endpoint; verify home/about pages before adding the edge layer.

## Lab 3 - Create Front Door Premium

1. Portal **Front Door and CDN profiles → Create → Azure Front Door → Custom create**.
2. Group `azlab08-frontdoor`, profile `lab08-profile`, tier **Premium**.
3. Add an endpoint with a unique name. Record the generated hostname after deployment.
4. Add origin group `lab08-origin-group`:
   - Health probe HTTPS, path `/index.html`, method HEAD, interval 30 seconds.
   - Keep default load-balancing settings for this single-origin lab.
5. Add origin `lab08-storage`:
   - Type **Storage (Static website)**.
   - Hostname: the exact website hostname from Lab 1, without `https://` or trailing slash.
   - Origin host header: same hostname.
   - HTTPS port 443; certificate subject-name validation enabled.
   - Enable **Private Link**; select the storage account, subresource **web**, and a supported Private Link location offered near the origin.
6. Add route `lab08-route`: endpoint's default domain enabled; pattern `/*`; origin group above; origin path blank.
7. Accept HTTP and HTTPS, enable **Redirect HTTP to HTTPS**, forwarding protocol **HTTPS only**.
8. Enable caching, ignore query strings for these static files, enable compression if offered.
9. Review/create. Wait for deployment.

## Lab 4 - Approve private connectivity

1. Open Storage account → **Networking → Private endpoint connections**.
2. Find the **pending request from this Front Door profile**. Inspect its details/message; approve that request only.
3. Return to Front Door origin settings and wait for Private Link approval/provisioning status to complete.
4. Open the Front Door HTTPS hostname. Expect the website; allow several minutes for configuration propagation.
5. If it fails, inspect origin hostname/header, web subresource and approval before disabling the public origin.

## Lab 5 - Disable direct public origin access

1. Storage account → **Networking → Public network access → Disabled**, save.
2. Wait for settings to propagate.
3. Open `https://FRONT-DOOR-HOSTNAME/about.html`; it should work.
4. Open the original Storage website endpoint in a new/private browser window; it should fail from your computer.
5. To prove Front Door is not merely serving old cached content, purge `/about.html` in the next step and fetch it through Front Door again. It must still succeed via the private origin.

## Lab 6 - Cache and purge checks

1. Front Door profile → **Overview / Endpoint → Purge**.
2. Select endpoint/domain, content path `/about.html`, then purge.
3. Wait for completion/propagation and fetch `/about.html` through Front Door.
4. In the Azure portal:

1. Open browser developer tools (**F12**) → **Network**, enable **Preserve log**, then browse to `https://YOUR-FRONT-DOOR-HOSTNAME/index.html` twice. Select the document request → **Headers**, record status and cache-related response headers.
2. Enter `http://YOUR-FRONT-DOOR-HOSTNAME/index.html`; inspect the redirect response and final HTTPS URL. A browser HTTPS-only feature may upgrade before contacting the server; note this if no HTTP request appears.
3. Browse to `https://YOUR-FRONT-DOOR-HOSTNAME/does-not-exist.html`; inspect the request status and error page.

Expected: HTTPS 200, HTTP redirect to HTTPS, missing page 404 with your error content. Cache-related headers may vary between edge locations and requests; inspect them but do not assume every second request must be a hit.

## Lab 7 - Publish version 2

Your portal upload now fails while public network access is disabled. That is expected; Front Door's managed private connection is not an upload path for your browser.

1. For this synthetic-content lab, temporarily set Storage public network access to **Enabled from all networks** to perform the upload. Record that direct website access is briefly possible again.
2. In the Azure portal:

1. In your local editor change `version 1` to `version 2` in `index.html`; save.
2. In the portal open **Storage account → Containers → $web → Upload**, select the edited `index.html`, enable **Overwrite if files already exist**, and upload. Keep the same blob name.

3. Immediately disable public network access again.
4. Purge both `/` and `/index.html` in Front Door; wait and refresh. Expected version 2.
5. Confirm direct-origin access fails again.

A production deployment should use a private build/deployment path or another explicitly controlled upload route, avoiding this temporary public-network toggle.

## Troubleshooting

| Symptom | Correction |
|---|---|
| Front Door 502/503 | Check origin type, web hostname/header, certificate validation and approved Private Link. |
| Site works only before network disable | Private Link was not actually provisioned; verify subresource web and purge to retest. |
| Upload denied after lockdown | Expected for portal browser outside the VNet; use the bounded Lab 7 procedure. |
| Old version persists | Purge both URL paths, wait for propagation and bypass browser cache. |
| Missing CSS | Verify blob key `css/site.css`, content upload and root-relative link. |

## Cleanup

1. Portal **Resource groups → azlab08-frontdoor → Overview**. Review the full resource list and confirm this is only your lab.
2. Select **Delete resource group**, type `azlab08-frontdoor`, and confirm **Delete**.
3. Wait for **Notifications** to report success; refresh **Resource groups** and **All resources** for this subscription and verify absence. Inspect any deletion error rather than assuming the resources are gone.

Delete group `azlab08-frontdoor`, wait for completion and verify it no longer exists. Confirm Front Door Premium profile and Storage account are removed. If approval/deletion dependencies block deletion, delete Front Door first, then its remaining lab private endpoint connection and Storage. Do not delete unrelated private endpoint requests.

## Completion checklist

- [ ] HTTPS website works with multiple pages/assets.
- [ ] Front Door can fetch uncached content while direct origin access is disabled.
- [ ] Version 2 visible after purge.
- [ ] Profile and origin storage deleted.

## References

- [Front Door private static website origin](https://learn.microsoft.com/en-us/azure/frontdoor/how-to-enable-private-link-storage-static-website)
- [Storage static websites](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blob-static-website)
- [Front Door cache purge](https://learn.microsoft.com/en-us/azure/frontdoor/standard-premium/how-to-cache-purge)
