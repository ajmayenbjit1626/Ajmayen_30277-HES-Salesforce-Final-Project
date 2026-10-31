# Helios Equipment Services – demo website

Static website (no build step) with a product catalogue and the Salesforce Web-to-Lead enquiry form (SAL-01).


Website live link: https://cute-eclair-e54799.netlify.app/

## Pages
| File | What it does |
|---|---|
| `index.html` | Home page: hero, product families, product catalogue (filter, search, sort, detail dialog), service plans, regions |
| `enquiry.html` | Web-to-Lead form. Opened from a product (`enquiry.html?product=CH-200`) it pre-selects the equipment type and fills the description |
| `service.html` | Web-to-Case service request form (INT-02); serial number is merged into Description |
| `thank-you.html` | Page Salesforce returns visitors to after submitting (`retURL`) |
| `404.html` | Not-found page (used by Netlify automatically) |

## Change the products
Edit `assets/js/products.js`. Codes, names, families and prices match the Salesforce products (WBS 4-01).

## Salesforce connection (don't change)
In `enquiry.html`: the form `action`, `oid`, `lead_source = Web`, and the field names `first_name`, `last_name`, `email`, `phone`,
`company`, `description` and the custom field IDs `00Nfj00005MxhMf` (Equipment Type), `00Nfj00005MxiLx` (Site Postcode),
`00Nfj00005MxjEn` (Indicative Budget), `00Nfj00005MxmUP` (Region).
`retURL` is set automatically to `<this site>/thank-you.html`.

In `service.html`: the form `action`, `orgid`, `recordType` (`012fj000008k6sD` = Case record type Technical, WBS 6-01),
and the field names `name`, `email`, `phone`, `company`, `subject`, `description`, `priority` and `00Nfj00005N7fBV` (Equipment Type), `type` (Case Type: Breakdown, Maintenance or Installation).

## Deploy to Netlify
Drag this folder (or the zip) onto https://app.netlify.com/drop, or onto your existing site's **Deploys** tab.
