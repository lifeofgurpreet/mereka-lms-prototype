# MCT User Import - Quick Reference

## Status: ✅ COMPLETED

**Date:** 2025-12-18
**Success Rate:** 98.77% (68,565 of 69,419 users)

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

```
Total users in database:    149,986
├─ Kajabi users:             80,561
├─ MCT users:                68,565
└─ Overlap:                       0
```

## Quick Commands

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

### Sample User Query
```bash
kubectl exec -n mereka-lms lms-75c446d865-c77cn -- python3 -c "
import os
os.environ['DJANGO_SETTINGS_MODULE'] = 'lms.envs.tutor.production'
import django
django.setup()
from django.contrib.auth import get_user_model
User = get_user_model()
user = User.objects.filter(email='gurpreet@biji-biji.com').first()
if user:
    print(f'Username: {user.username}')
    print(f'Email: {user.email}')
    print(f'Name: {user.profile.name}')
"
```

## Files Location

### In Repository
- Import Script: `/scripts/migrations/mct/scripts/openedx_bulk_import_mct.py`
- K8s Runner: `/scripts/migrations/mct/scripts/run_user_import_k8s.sh`
- Test Script: `/scripts/migrations/mct/scripts/test_user_import.sh`
- Import Log: `/var/migrations/mct/user_import_log_2025-12-18.txt`

### In K8s Pod
- CSV Data: `/tmp/mct_import/users.csv`
- Import Script: `/tmp/mct_import/openedx_bulk_import_mct.py`
- State File: `/tmp/mct_import/user_import.state`

### Documentation
- Summary: `/MCT_USER_IMPORT_SUMMARY.md`
- Full Report: `/docs/migrations/mct/MCT_USER_IMPORT_COMPLETE.md`
- This Guide: `/docs/migrations/mct/QUICK_REFERENCE_USER_IMPORT.md`

## Sample Users (Verified Imported)

| Username | Email | Name | Country |
|----------|-------|------|---------|
| gurpreet | gurpreet@biji-biji.com | Gurpreet Singh Admin | - |
| jose2417sby | jose2417sby@gmail.com | Yoseph Lidi S.Fil | Indonesia |
| wachidamin72 | wachidamin72@guru.sd.belajar.id | Wachid Amin | Indonesia |
| syaffaazzahra5 | syaffaazzahra5@gmail.com | syaffa az zahra | Indonesia |

## Known Issues

### Profile Creation Failures (854 users)
- Error: `Field 'allow_certificate' doesn't have a default value`
- Impact: User accounts created but profiles incomplete
- Resolution: Post-import cleanup script (optional, low priority)

### Username Conflicts (225 users)
- Resolution: Appended email hash to username
- Example: `john_doe` → `john_doe_a1b2c3`
- Original username preserved in metadata

## Next Steps

1. ✅ User Import Complete
2. ⏭️ **Proceed with Enrollment Import**
   - Source: `/var/migrations/mct/transformed/enrollments_categories.csv`
   - Count: ~31.8 million enrollments
   - Command: `openedx_bulk_import_mct.py enrollments`
3. ⏸️ Fix failed user profiles (optional)
4. ⏸️ Course import (pending)

## Need Help?

See full documentation:
- Complete report: `/docs/migrations/mct/MCT_USER_IMPORT_COMPLETE.md`
- Executive summary: `/MCT_USER_IMPORT_SUMMARY.md`
- Migration README: `/scripts/migrations/mct/README.md`
