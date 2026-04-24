# Django Raw SQL Bypass - Skill Documentation
_Audience: Platform Engineers • Owner: Ops Domain Owner • Last verified: 2026-03-06 • Status: supporting_

When Django ORM operations fail due to signals triggering Celery tasks (with unavailable broker), use raw SQL to bypass the ORM layer entirely.

## Problem

Django models often have `post_save` signals that trigger Celery tasks. In Kubernetes pods where the Celery broker (RabbitMQ/Redis) isn't directly accessible, these signals cause failures like:

```
kombu.exceptions.OperationalError: [Errno 111] Connection refused
```

Common scenarios:
- Discovery service's `update_enterprise_inclusion_for_courses_and_programs` signal
- Any model with async task triggers on save

## Solution: Raw SQL via Django Connection

Use Django's database connection cursor to execute raw SQL, completely bypassing the ORM and its signals.

```python
#!/usr/bin/env python
import sys
import os
import uuid
from datetime import datetime

# Setup Django
sys.path.insert(0, '/openedx/discovery')  # Adjust path for target service
os.chdir('/openedx/discovery')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'course_discovery.settings.production')

import django
django.setup()

from django.db import connection

cursor = connection.cursor()

# Execute raw SQL
cursor.execute("INSERT INTO table_name (col1, col2) VALUES (%s, %s)", [val1, val2])
connection.commit()

cursor.close()
```

## Key Considerations

### 1. UUID Format

Open edX uses `char(32)` for UUID fields (no dashes):

```python
# WRONG - 36 characters with dashes
uuid_val = str(uuid.uuid4())  # "550e8400-e29b-41d4-a716-446655440000"

# CORRECT - 32 characters without dashes
uuid_val = uuid.uuid4().hex   # "550e8400e29b41d4a716446655440000"
```

### 2. MySQL Reserved Words

Escape reserved words with backticks:

```sql
-- WRONG
SELECT id FROM table WHERE key = 'value'

-- CORRECT
SELECT id FROM table WHERE `key` = 'value'
```

Common reserved words in Open edX schemas: `key`, `order`, `group`, `index`

### 3. Required Fields Without Defaults

Check table schema before INSERT:

```python
cursor.execute('DESCRIBE table_name')
for row in cursor.fetchall():
    # row[4] is default value, row[2] is nullable
    if row[4] is None and row[2] == 'NO':
        print(f'{row[0]}: REQUIRED (no default)')
```

### 4. Many-to-Many Relationships

Use `INSERT IGNORE` for junction tables to avoid duplicates:

```python
cursor.execute("""
    INSERT IGNORE INTO program_authoring_organizations (program_id, organization_id)
    VALUES (%s, %s)
""", [program_id, org_id])
```

## Example: Discovery Programs Creation

Full working script used for MCT migration:

**Location**: `scripts/migrations/mct/create_programs_sql.py`

**Usage**:
```bash
# Copy script to pod
kubectl cp scripts/migrations/mct/create_programs_sql.py \
  mereka-lms/discovery-xxx:/tmp/create_programs_sql.py

# Execute
kubectl exec -n mereka-lms discovery-xxx -- \
  python /tmp/create_programs_sql.py
```

**Key Pattern**:
```python
from django.db import connection

cursor = connection.cursor()

# Check if exists first
cursor.execute("SELECT id FROM table WHERE slug = %s", [slug])
row = cursor.fetchone()

if row:
    entity_id = row[0]
    print(f"Exists: ID {entity_id}")
else:
    # Create with all required fields
    now = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    cursor.execute("""
        INSERT INTO table (uuid, created, modified, name, slug, required_field1, required_field2)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
    """, [uuid.uuid4().hex, now, now, name, slug, False, ''])
    connection.commit()

    cursor.execute("SELECT id FROM table WHERE slug = %s", [slug])
    entity_id = cursor.fetchone()[0]
    print(f"Created: ID {entity_id}")

cursor.close()
```

## When to Use This Method

| Situation | Use Raw SQL? |
|-----------|--------------|
| Celery broker unavailable | ✅ Yes |
| Bulk data import (thousands of rows) | ✅ Yes (faster) |
| One-time migration scripts | ✅ Yes |
| API is read-only (like Discovery Programs) | ✅ Yes |
| Regular application code | ❌ No, use ORM |
| Need signal side-effects | ❌ No, use ORM |

## Alternative Approaches (When They Work)

### 1. CELERY_TASK_ALWAYS_EAGER

Set before Django loads to run tasks synchronously:

```python
os.environ['CELERY_TASK_ALWAYS_EAGER'] = 'true'
```

**Limitation**: Doesn't always work if Celery app is already configured.

### 2. Disconnect Signals

```python
from django.db.models.signals import post_save
from myapp.signals import my_signal_handler
from myapp.models import MyModel

post_save.disconnect(my_signal_handler, sender=MyModel)
```

**Limitation**: Must disconnect before model import, complex in practice.

### 3. Django Management Commands

Some services have built-in management commands:

```bash
./manage.py create_program --partner sof --title "My Program"
```

**Limitation**: Not always available for bulk operations.

## Services Where This Applies

| Service | Common Use Case | Settings Module |
|---------|-----------------|-----------------|
| Discovery | Programs, Organizations, ProgramTypes | `course_discovery.settings.production` |
| LMS | Enrollments, Users (rare) | `lms.envs.production` |
| Credentials | Program Certificates | `credentials.settings.production` |
| Ecommerce | Products, Coupons | `ecommerce.settings.production` |

## Troubleshooting

### "Data too long for column 'uuid'"
Use `uuid.uuid4().hex` instead of `str(uuid.uuid4())`

### "Field 'X' doesn't have a default value"
Add the field to your INSERT with appropriate default value

### "Table 'X' doesn't exist"
Check if you're using the correct database. Some services use separate DBs.

### "You have an error in SQL syntax near 'key'"
Escape reserved words with backticks: `` `key` ``

## Related Files

- `scripts/migrations/mct/create_programs_sql.py` - Programs creation example
- `scripts/migrations/mct/create_programs_orm.py` - ORM version (for reference)
- `var/migrations/mct/programs_mapping.json` - Data mapping file
