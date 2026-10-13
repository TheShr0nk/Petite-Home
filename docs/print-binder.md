# The printed binder

A bound, tabbed copy of the Family File, printed on demand and mailed. The
app renders the PDF; the website charges the card and places the print job.
This file is the contract between the two, plus the vendor recommendation.

## Why the website, not in-app purchase

Apple does not allow in-app purchase for physical goods and requires another
payment method for them (App Review Guidelines 3.1.3(e)). So the app opens a
Stripe Checkout page in an in-app Safari view. The card and the shipping
address never touch the app, which also keeps the privacy label simple: the
app sends one PDF to petitehome.co, nothing else.

## Contract the app already implements

`PetiteHome/Services/PrintOrderService.swift` calls two routes on
petitehome.co. Build them in `petite-powder/02-web/src/app/api/print-orders/`.

### GET /api/print-orders/quote

Returns the current price so the app can show it before checkout. Shape:

```json
{ "price": "$49", "shipping": "Free in the US", "days": "7 to 10" }
```

If the route is missing or fails, the app shows "Shown at checkout" and still
lets the person continue.

### POST /api/print-orders (multipart/form-data)

Fields: `file` (application/pdf, the sealed Family File), `title`, `pages`
(integer), `includeVault` ("true" or "false"), `source` ("ios_app").

1. Validate: PDF, under 40 MB, 4 to 400 pages, US Letter.
2. Store the PDF privately (Vercel Blob with a private access token, or S3)
   under an order id `po_<random>`. Never a public URL: the file holds a
   family's private information. Delete it 30 days after the order ships.
3. Create a Stripe Checkout Session in `payment` mode with one line item (the
   binder), `shipping_address_collection` for US (and CA if the vendor ships
   there), `metadata.orderId`, `success_url` and `cancel_url` on
   petitehome.co (a simple "it's on its way" page and a "no charge" page).
4. Respond `201 { "checkoutUrl": session.url, "orderId": "po_..." }`.

Errors: `4xx { "error": "A sentence the app can show." }`. The app shows it
under the button.

### POST /api/print-orders/webhook (Stripe)

On `checkout.session.completed`: load the stored PDF, place the print job
with the vendor using the session's shipping address, store the vendor job
id, and email the receipt plus tracking through Klaviyo (a `Binder Ordered`
event with the order id, so the flow can send the tracking email when the
vendor reports shipment). On vendor shipment webhooks, email tracking.

## Vendor

Use a print-on-demand API so no one touches orders by hand:

- **Lulu Print API** (api.lulu.com). Coil-bound, 8.5 × 11, black and white
  interior on 60# paper, full-colour cover, ships from US facilities, has a
  sandbox. The product is identified by a "pod package id" string that
  encodes trim, binding and paper; pick coil binding ("CO") so it lies flat.
  Confirm the exact id and the unit cost in their pricing calculator, then set
  the Stripe price at roughly three times the landed cost. Their job accepts
  a cover PDF and an interior PDF by URL: hand it a short-lived signed URL
  to the stored file, never a permanent one.
- Alternatives with similar APIs: Peecho, Mixam. Blurb and Printful do not
  fit (photo books and merch).

Tabs: on-demand printers do not insert physical tabs. Either print a tab
strip on each section's first page (the exporter can draw a shaded edge
with the section name; add that as a `tier: .binder` variant) or ship a
sheet of adhesive tabs with the order. The shaded edge is the cheap one.

Cover: add a cover PDF generator on the website using the brand tokens
(`docs/lead-magnets.md` has them): powder blue, the wordmark, "The Family
File", the family name and the date. The app sends `title` for this.

## What the app does today

- Family File → Share it → "Paper copy, PDF or a printed binder" opens the
  paper sheet: order a binder, print at home (AirPrint), export the PDF, or
  export the sealed copy.
- "Order a binder" shows the quote, a toggle for the vault appendix (off by
  default, with a warning), then renders the PDF, posts it, and opens the
  checkout URL in Safari inside the app.
- The trusted-person sheet points to the same paper options, since the
  guardian is who a binder is for.

## Privacy label

Add "Other user content" (the PDF) as data collected for app functionality,
not linked to identity, in the App Privacy questionnaire, and the same entry
in `PrivacyInfo.xcprivacy`, once the website routes exist and the feature is
live. Until then the app can call the route and show its error.
