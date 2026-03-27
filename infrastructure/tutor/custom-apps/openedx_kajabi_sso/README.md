# Kajabi SSO Integration for Open edX

This Django app provides Single Sign-On (SSO) integration for Kajabi-migrated users in the Mereka Academy LMS.

## Features

- **OAuth2 Authentication Backend**: Seamless SSO for Kajabi users
- **Bulk CSV Import**: Import hundreds of Kajabi users at once
- **Email Deduplication**: Prevents duplicate accounts during migration
- **Welcome Emails**: Automated welcome emails with SSO setup instructions
- **SSO Fallback**: Email/password login always works even if SSO fails
- **Admin Interface**: Full Django admin integration for managing SSO links

## Architecture

### Models

#### `KajabiSsoLink`
Links an Open edX user account to their Kajabi SSO credentials.

**Key Fields**:
- `user`: OneToOne relationship with Open edX User
- `kajabi_email`: Original Kajabi email (indexed for lookups)
- `kajabi_user_id`: External Kajabi user ID (optional)
- `sso_provider`: OAuth2 client slug (default: `mereka-kajabi-sso`)
- `is_active`: Whether SSO is active for this user
- `welcome_email_sent`: Tracks welcome email delivery
- `last_sso_login_at`: Last successful SSO login timestamp
- `sso_failures_count`: Count of consecutive SSO failures

#### `KajabiImportBatch`
Tracks bulk imports of Kajabi users from CSV files.

**Key Fields**:
- `csv_filename`: Name of the imported CSV file
- `total_rows`: Total number of rows processed
- `created_count`: New user accounts created
- `linked_count`: Existing users linked to SSO
- `skipped_count`: Duplicates skipped
- `error_count`: Rows that failed to import
- `status`: Import status (pending/in_progress/completed/failed)
- `errors_json`: Row-by-row error log

### Authentication Backend

`KajabiSsoBackend` integrates with Django's authentication system:

1. Checks if Kajabi SSO is enabled
2. Looks up `KajabiSsoLink` by email
3. If found and active, authenticates user
4. If SSO fails, returns `None` → falls through to email/password backend

**Critical**: The backend is appended to `AUTHENTICATION_BACKENDS` (not prepended), ensuring email/password login always works as fallback.

### Business Logic (API)

**`import_kajabi_csv(csv_file_path, imported_by=None, send_welcome=True)`**
- Imports Kajabi users from CSV
- CSV format: `email,first_name,last_name,kajabi_user_id`
- Creates new users or links existing users
- Sends welcome emails to new users (optional)
- Returns `KajabiImportBatch` with statistics

**`link_kajabi_user(email, user=None, kajabi_user_id=None)`**
- Links a single Kajabi user to LMS account
- Idempotent (safe to call multiple times)
- Case-insensitive email lookup

**`send_welcome_email(user, kajabi_sso_link)`**
- Sends welcome email with SSO setup instructions
- Only sends if `welcome_email_sent` is False
- Uses HTML + plain text templates

**`generate_unique_username(email)`**
- Generates unique username from email
- Strategy: email prefix → prefix_1 → prefix_2 → etc.
- Max 30 characters (Django limit)

## Usage

### Environment Variables

Set these in your LMS settings:

```python
# Enable Kajabi SSO (default: false)
KAJABI_SSO_ENABLED=true

# OAuth2 client slug (default: mereka-kajabi-sso)
KAJABI_SSO_CLIENT_SLUG=mereka-kajabi-sso

# Enable welcome emails (default: false)
KAJABI_WELCOME_EMAIL_ENABLED=true

# Email settings
KAJABI_WELCOME_EMAIL_FROM=noreply@mereka.io
KAJABI_WELCOME_EMAIL_SUPPORT=support@mereka.io
```

**Important**: All flags default to `false` for safety. Enable only in production after testing.

### Bulk Import from CSV

#### CSV Format

Create a CSV file with the following columns:

```csv
email,first_name,last_name,kajabi_user_id
user1@example.com,John,Doe,kaj_123
user2@example.com,Jane,Smith,kaj_456
```

**Required columns**: `email`, `first_name`, `last_name`
**Optional columns**: `kajabi_user_id`

#### Import Command

```bash
# Basic import
python manage.py import_kajabi_users --csv-file /path/to/users.csv

# Skip welcome emails
python manage.py import_kajabi_users --csv-file /path/to/users.csv --no-welcome

# Dry run (preview only, not yet implemented)
python manage.py import_kajabi_users --csv-file /path/to/users.csv --dry-run
```

#### Import Results

The command prints a summary:

```
=== Import Summary ===
Total rows processed: 500
New users created: 350
Existing users linked: 140
Rows skipped (duplicates): 10
Errors encountered: 0

Import batch ID: abc123-def456-...
Status: completed
```

### Django Admin

Access the admin interface at `/admin/openedx_kajabi_sso/`:

- **Kajabi SSO Links**: View and manage individual SSO links
  - Filter by active status, welcome email sent, SSO provider
  - Search by email, username, Kajabi user ID
  - View SSO login history and failure counts

- **Kajabi Import Batches**: View bulk import history
  - See statistics for each import
  - View row-by-row error logs
  - Track import status

### Programmatic Usage

```python
from openedx_kajabi_sso.api import (
    import_kajabi_csv,
    link_kajabi_user,
    send_welcome_email,
)

# Bulk import
batch = import_kajabi_csv(
    csv_file_path='/path/to/users.csv',
    imported_by=request.user,  # Optional admin user
    send_welcome=True
)
print(f"Created {batch.created_count} users")

# Link single user
from django.contrib.auth import get_user_model
User = get_user_model()

user = User.objects.get(email='user@example.com')
sso_link = link_kajabi_user(
    email='user@example.com',
    user=user,
    kajabi_user_id='kaj_123'
)

# Send welcome email manually
send_welcome_email(user, sso_link)
```

## Acceptance Criteria Coverage

| AC | Description | Implementation |
|----|-------------|----------------|
| AC-SSO-001 | OAuth2 client registered and user matched via SSO | `KajabiSsoBackend.authenticate()` |
| AC-SSO-002 | Bulk import of 500-user CSV with zero duplicates | `import_kajabi_csv()`, `KajabiImportBatch` |
| AC-SSO-003 | SSO failure falls back to email/password | `KajabiSsoBackend` returns `None` on failure |
| AC-SSO-004 | No duplicate accounts (email + username dedup) | `link_kajabi_user()`, `generate_unique_username()` |
| AC-SSO-005 | Welcome email sent to migrated users | `send_welcome_email()` |
| AC-NEG-SSO-001 | MUST NOT create duplicates | `_import_single_user()` checks `existing_link` |
| AC-NEG-SSO-002 | MUST NOT prevent email/password login | Backend appended (not prepended) |
| AC-NEG-SSO-003 | MUST NOT send duplicate welcome emails | `send_welcome_email()` checks `welcome_email_sent` |

## Security Considerations

- **No Passwords Stored**: This app never stores Kajabi passwords, only links accounts
- **Email Normalization**: All emails normalized to lowercase to prevent case-sensitivity bypasses
- **Fallback Mandatory**: `KAJABI_SSO_FALLBACK_ENABLED` is hardcoded to `True` and cannot be disabled
- **Idempotent Operations**: `get_or_create` used throughout to prevent race conditions
- **SSO Failure Tracking**: `sso_failures_count` tracks suspicious activity

## Testing

Run the verification script:

```bash
bash scripts/qa/verify-kajabi-sso.sh --skip-cluster
```

This checks:
- All files exist
- All models have required fields
- All functions implement required logic
- Settings are properly configured
- Admin is registered
- Negative assertions are enforced

## Migration Checklist

Before migrating Kajabi users to production:

1. **Export Kajabi user database** to CSV
2. **Test import on staging** with a small sample (10-20 users)
3. **Verify SSO login works** for test users
4. **Enable feature flags** in production:
   ```python
   KAJABI_SSO_ENABLED=true
   KAJABI_WELCOME_EMAIL_ENABLED=true
   ```
5. **Run full import** with `--no-welcome` first (test without emails)
6. **Verify results** in Django admin
7. **Re-run import with welcome emails** if needed
8. **Monitor SSO login metrics** via `KajabiSsoLink.last_sso_login_at`

## Troubleshooting

### Import fails with "CSV missing required columns"

Ensure your CSV has headers: `email,first_name,last_name`

### Users not authenticating via SSO

1. Check `KAJABI_SSO_ENABLED=true` in settings
2. Verify `KajabiSsoLink` exists for user: `KajabiSsoLink.objects.filter(kajabi_email='user@example.com')`
3. Check `is_active=True` on SSO link
4. Review `sso_failures_count` in Django admin

### Welcome emails not sending

1. Check `KAJABI_WELCOME_EMAIL_ENABLED=true` in settings
2. Verify email configuration in Django settings
3. Check `welcome_email_sent` flag in Django admin

## Development

### Running Migrations

```bash
# Generate migrations
python manage.py makemigrations openedx_kajabi_sso

# Apply migrations
python manage.py migrate openedx_kajabi_sso
```

### Adding New Fields

1. Add field to `models.py`
2. Run `makemigrations`
3. Update `admin.py` to display new field
4. Update verification script if field is critical

## Support

For questions or issues, contact:
- **Email**: tech@mereka.io
- **Docs**: See `CLAUDE.md` in repository root
- **Bead**: mereka-lms-f98 (Kajabi SSO implementation)

## License

MIT License - Mereka Team © 2026
