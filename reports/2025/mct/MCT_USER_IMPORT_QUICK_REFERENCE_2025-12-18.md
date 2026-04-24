# MCT User Import Quick Reference (Historical Snapshot)

_Historical execution snapshot captured on 2025-12-18._

This report preserves the completed MCT user-import quick summary that was
previously stored in the active migration reference root.

## Completion Snapshot

- Status: complete
- Date: 2025-12-18
- Success rate: 98.77% (68,565 of 69,419 users)

## Key Numbers

| Metric | Value |
|--------|-------|
| Total Users Processed | 69,419 |
| Successfully Imported | 68,565 |
| Failed | 854 |
| Username Conflicts Resolved | 225 |
| Import Duration | 30 minutes |
| Processing Speed | ~2,300 users/minute |

## Database Status

```text
Total users in database:    149,986
├─ Kajabi users:             80,561
├─ MCT users:                68,565
└─ Overlap:                       0
```

## Quick Commands Used During The Historical Import

### Check Import Status
```bash
kubectl exec -n mereka-lms lms-75c446d865-c77cn -- \
  cat /tmp/mct_import/user_import.state
```

### Verify User Count
```bash
kubectl exec -n mereka-lms lms-75c446d865-c77cn -- python3 -c "
import os
os.environ['DJANGO_SETTINGS_MODULE'] = 'lms.envs.tutor.production'
import django
django.setup()
from common.djangoapps.student.models import UserProfile
count = UserProfile.objects.filter(meta__contains='mct_user_id').count()
print(f'MCT users: {count:,}')
"
```

## File Locations Recorded At The Time

### In Repository
- Import Script: `/scripts/migrations/mct/openedx_bulk_import_mct.py`
- K8s Runner: `/scripts/migrations/mct/run_user_import_k8s.sh`
- Test Script: `/scripts/migrations/mct/test_user_import.sh`
- Import Log: `/var/migrations/mct/user_import_log_2025-12-18.txt`

### In K8s Pod
- CSV Data: `/tmp/mct_import/users.csv`
- Import Script: `/tmp/mct_import/openedx_bulk_import_mct.py`
- State File: `/tmp/mct_import/user_import.state`

## Related Historical Documentation

- Full Report: `/docs/archive/reports/mct/MCT_USER_IMPORT_COMPLETE.md`
- This historical quick reference: `/reports/2025/mct/MCT_USER_IMPORT_QUICK_REFERENCE_2025-12-18.md`

## Known Issues At The Time

### Profile Creation Failures (854 users)

- Error: `Field 'allow_certificate' doesn't have a default value`
- Impact: User accounts created but profiles incomplete
- Resolution: Post-import cleanup script (optional, low priority)

### Username Conflicts (225 users)
- Resolution: Appended email hash to username
- Example: `john_doe` -> `john_doe_a1b2c3`
- Original username preserved in metadata

## Historical Next Steps

1. User import complete
2. Proceed with enrollment import
3. Fix failed user profiles (optional)
4. Course import (pending at the time)
