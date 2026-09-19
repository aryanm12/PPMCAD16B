# 08 - Front Door and Static Websites: Brief Notes

**Learning interface:** Use the Azure portal for this topic’s resource settings, monitoring and cleanup. The companion hands-on gives the exact pages and values.

**Read before:** [Lab 08 - Front Door and Storage website](08-Front-Door-and-Storage-Static-Website.md)  
**Reading time:** 6–8 minutes. Review [foundation notes](01-Lab-Preparation-and-Cost-Controls-brief-notes.md) for Storage accounts and containers.

## What you are publishing

A **static website** serves files such as HTML, CSS, images and browser JavaScript. It does not run server-side Python/PHP merely because those files were uploaded. Your browser renders the HTML and fetches its linked assets.

```text
Browser → Front Door HTTPS endpoint → cache or origin fetch
                                           |
                                           +→ private Storage website origin
```

## Terms used in the guide

| Term | Meaning |
|---|---|
| Front Door | Azure's global HTTP(S) edge delivery/routing service |
| Edge location | A service location near users where requests may be handled/cached |
| Origin | The source from which Front Door fetches content |
| Origin group | A collection of origin destinations and their health/routing settings |
| Endpoint | The frontend hostname clients use |
| Route | Rules connecting frontend domains/path patterns to origin groups |
| Origin host header | The hostname Front Door presents to the origin in its HTTP request |
| Cache | A reusable copy of a response held closer to clients |
| TTL | Time to live: how long cached content can remain fresh under its caching rules |
| Purge | Ask the edge service to remove cached copies of selected paths |

The endpoint hostname, Storage account blob hostname and Storage **website** hostname are different. Selecting the wrong origin hostname or host header can fail even when all files exist.

## Storage website behavior

Enabling Static website creates/uses the special **`$web` container**. The **index document** is the file served for the root request. The **error document** supplies missing-page content. Object names such as `css/site.css` must match the paths in your HTML.

A significant AWS-to-Azure trap: disabling anonymous access to ordinary blob containers does not by itself make the static website endpoint private. The lab uses a Storage network restriction plus Front Door Private Link to protect the origin path. See [Storage static websites](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blob-static-website).

## What Private Link changes

Front Door **Premium** supports the private origin connection used here. You approve the request on the Storage account and select the **web** subresource because the origin is the static website service. Selecting **blob** is not automatically the same thing.

After you disable public network access, ordinary internet clients should fail when going directly to the origin, while Front Door should still fetch content privately. A cached page alone is insufficient proof: purge a path and fetch it again to exercise the origin connection. See [Front Door private website origins](https://learn.microsoft.com/en-us/azure/frontdoor/how-to-enable-private-link-storage-static-website).

## Publishing is not the same path as reading

The Front Door connection serves users; it is not a private upload tunnel for your browser session. When the Storage public network is disabled, an upload from portal browser outside the VNet can fail despite valid RBAC.

The exercise temporarily reopens the public network for synthetic-content updates, then closes it. A real delivery process should design an appropriate private or tightly controlled publishing path instead.

## Cache tests need careful interpretation

Changing `index.html` in Storage does not guarantee every user immediately receives the new version. Browser caching and edge caching are separate. Purging `/index.html` may not cover a separately cached `/` request; the lab tests both.

**HTTP redirect** moves a client to HTTPS. **HTTPS** protects the connection but does not mean the page is restricted to authenticated users. Your website remains intentionally public through Front Door; only the direct origin path is restricted.

## AWS connection

Front Door has responsibilities familiar from CloudFront. Storage's website service has similarities to S3 website hosting, but authentication, private-origin mechanisms, SKUs and endpoint types differ. Do not apply an S3 Origin Access Control policy to Azure: this lab uses Azure's supported Private Link path.

## Check your understanding

1. Can you prove private-origin access by viewing a page that was already cached?
2. Will uploading a new file necessarily invalidate all cached copies?
3. Why might portal upload fail while users can still read the site?

**Answers:** (1) No; force an origin fetch after public access is disabled. (2) No. (3) Publishing and Front Door's private-origin connection use different network paths.

**Ready for the lab:** You can distinguish frontend, origin, cache and upload paths.
