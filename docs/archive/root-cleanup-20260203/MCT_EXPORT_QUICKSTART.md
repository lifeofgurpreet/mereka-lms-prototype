# MCT Export - Quick Start Guide

**After applying the fixes, follow these steps to export ALL data:**

---

## Step 1: Set Credentials

```bash
export MCT_BASE_URL=https://learn.skillourfuture.org
export MCT_API_URI=api://e8edea94-e86f-4dc7-857e-3c5c09bb76d3
export MCT_CLIENT_ID=<your-client-id>
export MCT_CLIENT_SECRET=<your-client-secret>
export MCT_TENANT_ID=<your-tenant-id>
```

---

## Step 2: Run Exports in Order

```bash
cd /home/dev/code/mereka-lms

# 1. Export categories (if not already done)
node scripts/migrations/mct/mct-export.mjs --resources categories

# 2. Export courses (FIXED - uses categories.ndjson)
node scripts/migrations/mct/mct-export.mjs --resources courses --force

# 3. Export enrollments (NEW - uses courses.ndjson)
node scripts/migrations/mct/mct-export.mjs --resources enrollments --force
```

---

## Step 3: Verify Results

```bash
# Check file sizes and line counts
ls -lh exports/mct/*.ndjson
wc -l exports/mct/*.ndjson

# Expected output:
#       1 categories.ndjson   (hierarchical structure)
#   100+ courses.ndjson       (all courses from 31 categories)
#  1000+ enrollments.ndjson   (real enrollment data)
#  69419 users.ndjson

# Run automated validation
./scripts/migrations/mct/test-export-fixes.sh
```

---

## Step 4: Inspect Data

```bash
# View categories structure
head -1 exports/mct/categories.ndjson | python3 -m json.tool | head -50

# View first 3 courses
head -3 exports/mct/courses.ndjson | python3 -m json.tool

# View first 3 enrollments
head -3 exports/mct/enrollments.ndjson | python3 -m json.tool

# Count categories in hierarchical structure
python3 -c "import json; data=json.load(open('exports/mct/categories.ndjson')); print(f'Categories: {len(data[\"Offers\"])}')"
```

---

## Expected Output

### Categories (No Change)
```json
{
  "Offers": [
    {
      "Id": 24,
      "Names": [{"LanguageCode": "en-US", "Value": " AI Fluency"}],
      "DefaultLanguageCode": "en-US",
      "Logo": "",
      "OrganizationId": 1,
      "OrganizationName": "Default"
    },
    // ... 30 more categories
  ]
}
```

### Courses (FIXED)
```json
{
  "CategoryId": 24,
  "CategoryName": " AI Fluency",
  "ProductId": 279,
  "CourseName": "Module 1: Introduction to Artificial Intelligence",
  "CourseDescription": "",
  "CompletionPercentage": 0,
  "CourseItemCount": 0,
  "Priority": "Default"
}
```

### Enrollments (NEW)
```json
{
  "courseId": 225,
  "User ID": "abc123-def456-ghi789",
  "First Name": "John",
  "Last Name": "Doe",
  "Email": "john.doe@example.com",
  "Completion %": "75",
  "Last Access Date": "2025-12-15",
  "Status": "In Progress"
}
```

---

## Troubleshooting

### Issue: "categories.ndjson not found"
```bash
node scripts/migrations/mct/mct-export.mjs --resources categories
```

### Issue: "courses.ndjson still has only 15 lines"
```bash
# Delete old file and re-export
rm exports/mct/courses.ndjson
node scripts/migrations/mct/mct-export.mjs --resources courses --force
```

### Issue: "enrollments.ndjson not created"
```bash
# Check courses.ndjson exists first
ls -lh exports/mct/courses.ndjson

# Then export enrollments
node scripts/migrations/mct/mct-export.mjs --resources enrollments --force
```

### Issue: "ZIP file warnings for enrollments"
Some large enrollment reports return ZIP files. This is normal - the script will skip those and log a warning. You may need to download them manually if needed.

---

## One-Liner for Full Export

```bash
node scripts/migrations/mct/mct-export.mjs --resources categories,courses,enrollments --force
```

**Note:** This exports all three in sequence with `--force` to overwrite existing files.

---

## Validation Commands

```bash
# Test 1: Verify 31 categories
python3 -c "import json; d=json.load(open('exports/mct/categories.ndjson')); assert len(d['Offers'])==31, 'Expected 31'; print('✅ 31 categories found')"

# Test 2: Verify courses > 15
python3 -c "c=len(open('exports/mct/courses.ndjson').readlines()); assert c>15, f'Only {c} courses'; print(f'✅ {c} courses found')"

# Test 3: Verify enrollments exist
python3 -c "import os; assert os.path.exists('exports/mct/enrollments.ndjson'), 'Missing enrollments'; print('✅ enrollments.ndjson exists')"

# Test 4: Verify enrollments have data
python3 -c "e=len(open('exports/mct/enrollments.ndjson').readlines()); assert e>0, 'No enrollments'; print(f'✅ {e} enrollments found')"
```

---

## Summary

✅ **Categories:** 1 line with 31 categories in hierarchical structure
✅ **Courses:** 100-300+ lines with all courses from all 31 categories
✅ **Enrollments:** 1000+ lines with real enrollment data per course

**Next:** Update `transform_data.py` to use real enrollment data instead of heuristic matching.
