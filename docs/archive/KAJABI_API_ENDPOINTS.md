# Kajabi Public API Endpoints Reference

**Source**: [Kajabi API Documentation](https://developers.kajabi.com/api-reference)

This document lists the **actual** endpoints available in the Kajabi Public API v1, based on the official documentation and what we've verified in our codebase.

## Authentication

- `POST /v1/oauth/token` - Get access token (client credentials flow)
- `POST /v1/oauth/revoke` - Revoke a token

## Available Endpoints

### Contacts
- `GET /v1/contacts` - List contacts
- `POST /v1/contacts` - Create a contact
- `GET /v1/contacts/{id}` - Contact details
- `PATCH /v1/contacts/{id}` - Update contact
- `DELETE /v1/contacts/{id}` - Delete contact
- `GET /v1/contacts/{id}/offers` - List contact's offers
- `POST /v1/contacts/{id}/offers` - Grant offer to contact
- `DELETE /v1/contacts/{id}/offers/{offer_id}` - Revoke offer from contact
- `PATCH /v1/contacts/{id}/offers` - Replace offers for contact
- `GET /v1/contacts/{id}/tags` - List contact's tags
- `POST /v1/contacts/{id}/tags` - Add tag to contact
- `DELETE /v1/contacts/{id}/tags/{tag_id}` - Remove tag from contact
- `PATCH /v1/contacts/{id}/tags` - Replace tags for contact

### Contact Notes
- `GET /v1/contact_notes` - List contact notes
- `POST /v1/contact_notes` - Create contact note
- `GET /v1/contact_notes/{id}` - Contact note details
- `DELETE /v1/contact_notes/{id}` - Delete contact note
- `PATCH /v1/contact_notes/{id}` - Update contact note

### Contact Tags
- `GET /v1/contact_tags` - List contact tags
- `GET /v1/contact_tags/{id}` - Contact tag details

### Customers
- `GET /v1/customers` - List customers
- `GET /v1/customers/{id}` - Customer details
- `GET /v1/customers/{id}/offers` - List customer's offers
- `POST /v1/customers/{id}/offers` - Grant offer to customer
- `DELETE /v1/customers/{id}/offers/{offer_id}` - Revoke offer from customer
- `PATCH /v1/customers/{id}/offers` - Replace offers for customer

### Products
- `GET /v1/products` - List products
- `GET /v1/products/{id}` - Product details

### Courses
- `GET /v1/courses` - List courses
- `GET /v1/courses/{id}` - Course details
  - Supports `include` parameter: `modules,lessons,lessons.media,offers`

### Offers
- `GET /v1/offers` - List offers
- `GET /v1/offers/{id}` - Offer details
- `GET /v1/offers/{id}/products` - List offer's products

### Purchases
- `GET /v1/purchases` - List purchases
- `GET /v1/purchases/{id}` - Purchase details
- `POST /v1/purchases/{id}/reactivate` - Reactivate purchase
- `POST /v1/purchases/{id}/deactivate` - Deactivate purchase
- `POST /v1/purchases/{id}/cancel_subscription` - Cancel subscription

### Orders
- `GET /v1/orders` - List orders
- `GET /v1/orders/{id}` - Order details

### Order Items
- `GET /v1/order_items` - List order items
- `GET /v1/order_items/{id}` - Order item details

### Transactions
- `GET /v1/transactions` - List transactions
- `GET /v1/transactions/{id}` - Transaction details

### Forms
- `GET /v1/forms` - List forms
- `GET /v1/forms/{id}` - Form details
- `POST /v1/forms/{id}/submit` - Submit form

### Form Submissions
- `GET /v1/form_submissions` - List form submissions
- `GET /v1/form_submissions/{id}` - Form submission details

### Custom Fields
- `GET /v1/custom_fields` - List custom fields
- `GET /v1/custom_fields/{id}` - Custom field details

### Sites
- `GET /v1/sites` - List sites
- `GET /v1/sites/{id}` - Site details
- `GET /v1/sites/{id}/blog_posts` - List blog posts
- `GET /v1/blog_posts/{id}` - Blog post details
- `GET /v1/sites/{id}/landing_pages` - List landing pages
- `GET /v1/landing_pages/{id}` - Landing page details
- `GET /v1/sites/{id}/website_pages` - List website pages
- `GET /v1/website_pages/{id}` - Website page details

### Webhooks
- `GET /api/v1/hooks` - List hooks
- `POST /api/v1/hooks` - Create hook
- `GET /api/v1/hooks/{id}` - Hook details
- `DELETE /api/v1/hooks/{id}` - Delete hook

### Me
- `GET /v1/me` - My user profile

### Version
- `GET /v1/version` - API version

## Endpoints That Do NOT Exist

Based on testing with the actual API, these endpoints return 404:

- ❌ `/v1/certificates` - **Not available**
- ❌ `/v1/completions` - **Not available**
- ❌ `/v1/course_completions` - **Not available**
- ❌ `/v1/achievements` - **Not available**
- ❌ `/v1/products/{id}/certificates` - **Not available**
- ❌ `/v1/products/{id}/completions` - **Not available**
- ❌ `/v1/products/{id}/students` - **Not available**
- ❌ `/v1/products/{id}/enrollments` - **Not available**
- ❌ `/v1/customers/{id}/certificates` - **Not available**
- ❌ `/v1/customers/{id}/completions` - **Not available**
- ❌ `/v1/purchases/{id}/certificates` - **Not available**
- ❌ `/v1/lessons/{id}` - Returns 404 (lesson details not available via API)

## Certificate Data Availability

**Verdict**: Certificate/completion data is **NOT available** via the Kajabi Public API.

### What We Can Use Instead:

1. **Purchase Data** (`/v1/purchases`) - Indicates enrollment/eligibility
   - A purchase represents a user enrolled in a product/course
   - Can be used as a proxy for "certificate eligibility"

2. **Manual Export** - From Kajabi Dashboard
   - Navigate to: Analytics → Certificates
   - Export CSV/Excel manually
   - This is the only way to get actual certificate issuance data

3. **Third-Party Integrations** - Via Zapier
   - Accredible, SimpleCert integrations
   - Requires manual setup and may have their own APIs

## Query Parameters

Most list endpoints support:
- `page[number]` - Page number (default: 1)
- `page[size]` - Page size (default: varies, max usually 100)
- `filter[field]` - Filter by field (e.g., `filter[site_id]=123`)
- `include` - Include related resources (e.g., `include=offers,tags,customer`)
- `fields[resource]` - Sparse fields (e.g., `fields[contacts]=name,email`)

## References

- [Kajabi API Documentation](https://developers.kajabi.com/api-reference)
- [Contact Details Endpoint](https://developers.kajabi.com/api-reference/contacts/contact-details)




