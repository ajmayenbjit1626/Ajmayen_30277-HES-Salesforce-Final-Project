# Manual setup steps (org rebuild checklist)

These settings live in Setup and are either not retrievable as metadata or need a manual step (verification email, password, licence). Do them in this order when building a new org, then deploy `force-app/`.

Placeholders: `<support mailbox>` = the Gmail account used as the HES support address (currently ajmayen420@gmail.com); `<test inbox>` = the inbox used for persona users and test customers (currently ajmayenfayek1@gmail.com).

## 1. Company and admin user (WBS 2-06 / 2-07)
- [ ] Admin user: Time Zone **(GMT+01:00/+02:00) Central European Time (Europe/Amsterdam)**, Locale **English (United Kingdom)**, Language English. Default Working Hours 8, Is Scheduled ticked (the admin is scheduled engineer #2).
- [ ] Business Hours **HES Working Week**: Active, time zone Europe/Amsterdam, Mon–Fri 24 hours, Sat–Sun closed.
- [ ] Holiday **Christmas Eve**: 24/12/2026, all day, not recurring; added to HES Working Week (Business Hours › Holidays › Add/Remove).
- [ ] Custom metadata record **HES Setting › Default**: Horizon Days 60, Business Hours Name `HES Working Week`, At Risk Days 90 (deployed with metadata; check after deploy).

## 2. Users and licences (WBS 3-01, see persona-mapping.md)
- [ ] Sam Rep: Profile Minimum Access - Salesforce, Manager = admin, Role Sales Representative, permission set HES Sales Representative, email `<test inbox>` with +sam tag.
- [ ] Eric Engineer: Profile Minimum Access - Salesforce, Role Field Engineer, permission set HES Field Engineer, Default Working Hours 8, Is Scheduled ticked.
- [ ] Admin: Role **Sales Manager** (needed so Finance sees admin-owned opportunities through "Pipeline to finance").
- [ ] Persona permission sets include **Lightning Experience User** (otherwise users open in Classic without an App Launcher).

## 3. Email deliverability and sender addresses (WBS 4-02, 5-03)
- [ ] Setup › Deliverability › Access level: **All email**.
- [ ] Organization-Wide Addresses (Purpose: User Selection, Allow All Profiles), each verified by clicking the link in the verification email:
  - **Helios Sales** – `<test inbox>` (lead acknowledgement, discount emails)
  - **Helios Service Desk** – `<support mailbox>` (case acknowledgements, satisfaction email)
- [ ] Classic email template folder **HES Email Templates** (Folder Unique Name HES_Email_Templates, Read Only, all users). Templates are deployed with metadata; check each has **Available For Use** ticked.

## 4. Web-to-Lead (WBS 4-02)
- [ ] Setup › Web-to-Lead › Edit › Web-to-Lead Enabled; Default Lead Creator: admin; Default Response Template: none (the email alert answers).
- [ ] Website `enquiry.html` posts to `https://webto.salesforce.com/servlet/servlet.WebToLead?encoding=UTF-8&orgId=<Org ID>` with `oid` = Org ID and `lead_source = Web`. Custom field IDs in the form (`00N…`) change in a new org: regenerate them with the Web-to-Lead HTML generator and update the website.

## 5. Email-to-Case (WBS 5-01, 5-04)
- [ ] Support Settings: Default Case Owner = admin, Automated Case User = admin, Notify Default Case Owner unticked, all Support Settings templates **None** (emails go through alerts), **Show Closed Statuses in Case Status Field** ticked (6-06).
- [ ] Email-to-Case settings: Enable Email-to-Case, Enable On-Demand Service, Lightning threading (email headers) on.
- [ ] Routing address **HES Support**: Email Address `<support mailbox>`, Save Email Headers ticked, Case Origin Email, Case Priority Medium, **Case Owner left blank** (if it is filled, the assignment rule does not run – found in 5-04 testing).
- [ ] Click the verification link sent to the support mailbox. Copy the Email Services Address (`…@….case.salesforce.com`).
- [ ] Gmail (support mailbox) › Settings › Forwarding and POP/IMAP › Add a forwarding address = the Email Services Address (no spaces). The Gmail confirmation code arrives as a new Case; open it, read the code, confirm in Gmail, then choose **Forward a copy of incoming mail to** › Save Changes.

## 6. Web-to-Case (WBS 5-02, 6-01)
- [ ] Setup › Web-to-Case › Enable; Default Case Origin Web; no response template.
- [ ] Website `service.html` posts to `https://webto.salesforce.com/servlet/servlet.WebToCase?encoding=UTF-8&orgId=<Org ID>` with `orgid`, `recordType` = ID of Case record type **Technical** (from Setup › Object Manager › Case › Record Types › Technical, address bar), and custom field `00N…` for Equipment Type. All three change in a new org.

## 7. Website (Netlify)
- [ ] Deploy the `helios-site` folder (Netlify › Deploys › drag and drop). Current site: sprightly-pothos-2e1dfb.netlify.app.
- [ ] After a new org: update `oid`/`orgid`, the `00N…` field IDs and `recordType` in `enquiry.html` and `service.html`.

## 8. Settings changed during testing (keep after a rebuild)
- [ ] Path Settings enabled (4-04).
- [ ] Case page layouts › Layout Properties › Case Assignment Checkbox: **Show on edit page** ticked, **Default unticked** (so editing an assigned case does not pull it back into a queue). Email Notification Checkbox **not shown**.
- [ ] Equipment page layout: remove the default global actions *New Contact*, *New Opportunity*, *New Lead* (cosmetic, pending).

## 9. Data that is not metadata (re-create or seed in 11-01)
- Products (8) with Standard Price Book entries (4-01).
- Skills (5): Chiller, Compressor, Air Dryer, Electrical, Refrigerant Handling (6-05).
- Junk Rule custom metadata records are metadata and deploy with `force-app/`.
