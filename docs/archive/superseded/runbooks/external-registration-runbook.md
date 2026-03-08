# External Registration via HubSpot Runbook
_Audience: Platform Eng + Marketing Operations • Owner: Engineering Lead • Last updated: 2026-02-10_

This runbook covers operational procedures for the HubSpot-to-Open edX registration service.

> **Status**: External registration is **not yet implemented** (Tier 3). This runbook documents target-state procedures.
> **Spec**: `specs/external-registration-hubspot_spec.md`
> **Testmap**: `specs/testmaps/external-registration-hubspot_spec.testmap.yml`

## Prerequisites

- HubSpot portal access (for webhook configuration)
- Kubernetes access to `mereka-lms` namespace
- Infisical access for HubSpot OAuth credentials
- SendGrid access for email template management

---

## Configuring HubSpot Webhook

### Procedure
1. Log in to HubSpot portal at `https://app.hubspot.com`
2. Navigate to **Settings** → **Integrations** → **Webhooks**
3. Click **Create webhook**
4. Configure webhook:
   - **Webhook URL**: `https://api.academyv2.mereka.io/hubspot/registration`
   - **Events**: Form submission (select registration form)
   - **Authentication**: v3 Signature (copy secret to Infisical)
5. Test webhook:
   - Submit test form with known email
   - Verify 200 OK response in HubSpot delivery log
6. Save and activate webhook

### Acceptance
- Webhook shows "Active" status in HubSpot
- Test submissions trigger 200 OK responses
- Webhook secret is stored in Infisical
- Service logs show successful signature verification

---

## Troubleshooting Failed Registrations

### Symptoms
- User submits HubSpot form but no Open edX account created
- Welcome email not received

### Diagnosis
1. Check webhook delivery logs in HubSpot:
   - Navigate to **Settings** → **Webhooks** → select webhook
   - Review recent deliveries for errors (4xx/5xx)
2. Check service logs:
   ```bash
   kubectl logs -n mereka-lms -l app.kubernetes.io/name=hubspot-registration --tail=100 | grep -i error
   ```
3. Identify common failure reasons:
   - **Signature verification failed**: Webhook secret mismatch
   - **User already exists**: Duplicate email (should be idempotent)
   - **LMS API timeout**: LMS registration endpoint slow/unavailable
   - **Invalid email format**: Malformed email in form submission

### Resolution
- **Signature mismatch**:
  ```bash
  # Update webhook secret in ExternalSecret
  kubectl edit secret hubspot-registration-secrets -n mereka-lms
  # Restart pods to pick up new secret
  kubectl rollout restart deployment hubspot-registration -n mereka-lms
  ```
- **Duplicate email** (idempotent behavior):
  ```bash
  # Verify user exists
  kubectl exec -n mereka-lms -l app.kubernetes.io/name=lms -- \
    python manage.py lms get_user --email <email>
  # Service should return 200 OK with existing user info
  ```
- **LMS API timeout**:
  ```bash
  # Check LMS health
  kubectl exec -n mereka-lms -l app.kubernetes.io/name=lms -- \
    curl http://localhost:8000/heartbeat
  # Increase timeout in service config if needed
  ```

### Acceptance
- Failed registrations are retried by HubSpot (up to 24 hours)
- Duplicate submissions are handled idempotently
- All failures are logged with error details
- Dead letter queue captures unrecoverable failures

---

## Manual User Creation (Fallback)

### Procedure (when webhook fails)
1. Identify failed submission:
   - Email address from support ticket
   - Form submission data from HubSpot
2. Manually create Open edX account via Django admin:
   - Navigate to `/admin/auth/user/add/`
   - Fill in: Username (derived from email), Email, Password (random)
3. Send welcome email manually:
   ```bash
   kubectl exec -n mereka-lms -l app.kubernetes.io/name=lms -- \
     python manage.py lms send_account_activation_email --email <email>
   ```
4. Log manual creation in service database:
   ```bash
   kubectl exec -n mereka-lms -l app.kubernetes.io/name=hubspot-registration -- \
     psql $DATABASE_URL -c "
     INSERT INTO manual_registrations (email, created_by, reason)
     VALUES ('<email>', 'admin', 'Webhook failure - manual fallback');
     "
   ```

### Acceptance
- User can log in with auto-generated credentials
- Welcome email is sent within 5 minutes
- Manual creation is logged for audit
- Root cause of webhook failure is documented

---

## Monitoring Registration Pipeline

### Key Metrics
```bash
# Registration success rate (should be >99.5%)
kubectl exec -n mereka-lms prometheus-0 -- \
  promtool query instant 'rate(hubspot_registration_success_total[5m]) / rate(hubspot_registration_attempts_total[5m])'

# Registration latency (p95 <10s)
kubectl exec -n mereka-lms prometheus-0 -- \
  promtool query instant 'histogram_quantile(0.95, hubspot_registration_duration_seconds_bucket)'

# Webhook signature failures (should be 0)
kubectl exec -n mereka-lms prometheus-0 -- \
  promtool query instant 'rate(hubspot_registration_signature_failures_total[5m])'
```

### Alerts
- **Critical**: Registration success rate <95% for 15 minutes
- **Warning**: Registration latency p95 >30s for 10 minutes
- **Critical**: Webhook signature failures >5 in 5 minutes
- **Warning**: Dead letter queue has >10 unprocessed messages

---

## Updating Welcome Email Template

### Procedure
1. Access SendGrid template editor at `https://mc.sendgrid.com/dynamic-templates`
2. Select template: "Mereka Academy - Welcome Email"
3. Edit template HTML/content
4. Test template with sample data:
   - Preview in email clients (Gmail, Outlook, Apple Mail)
   - Send test email to team members
5. Publish template (creates new version)
6. Update service config with new template ID:
   ```bash
   kubectl set env deployment/hubspot-registration \
     SENDGRID_WELCOME_TEMPLATE_ID=<new-template-id> \
     -n mereka-lms
   ```
7. Verify new template is used:
   - Trigger test registration
   - Check email uses updated content

### Acceptance
- New template renders correctly in major email clients
- Template includes all required elements (login link, support contact)
- Multi-language support maintained (EN, MS, ZH, VN, PH)
- Template version is tagged in SendGrid

---

## Handling High-Volume Registration Bursts

### Scenario
Conference booth or marketing campaign generates 100+ registrations in 5 minutes.

### Procedure
1. Monitor HPA scaling:
   ```bash
   kubectl get hpa hubspot-registration -n mereka-lms -w
   ```
2. Verify pods scale up to handle load (max: 10 replicas)
3. Monitor queue depth:
   ```bash
   kubectl exec -n mereka-lms redis-0 -- redis-cli LLEN registration_queue
   ```
4. If queue grows >100, manually scale up:
   ```bash
   kubectl scale deployment hubspot-registration --replicas=10 -n mereka-lms
   ```
5. Monitor LMS registration API latency:
   - Should stay <5s per request
   - If LMS is bottleneck, consider rate limiting HubSpot

### Acceptance
- Service handles bursts of 100+ registrations without failures
- HPA scales pods automatically based on CPU/memory
- All registrations complete within 10 minutes of submission
- No rate limiting from SendGrid (stays under 1000/min limit)

---

## Related Documentation
- **Spec**: `specs/external-registration-hubspot_spec.md`
- **HubSpot Webhook Service**: `services/hubspot-webhook/README.md`
- **Email Pipeline**: `specs/email-notifications-pipeline_spec.md`
- **General Troubleshooting**: `docs/runbooks/operations/TROUBLESHOOTING.md`
