# Content Libraries v2 Runbook
_Audience: Platform Eng + Content Team • Owner: Engineering Lead • Last updated: 2026-02-10_

This runbook covers operational procedures for Content Libraries v2 (Blockstore-backed libraries in Redwood).

> **Status**: Content Libraries v2 is enabled but not yet fully deployed (Tier 3). This runbook documents target-state procedures.
> **Spec**: `specs/content-libraries-v2_spec.md`
> **Testmap**: `specs/testmaps/content-libraries-v2_testmap.yaml`

## Prerequisites

- Studio (CMS) admin access
- Organization membership for the library you want to manage
- `CONTENT_LIBRARY_CREATOR` permission (for creating new libraries)

---

## Creating a Content Library v2

### Procedure
1. Log in to Studio at `https://studio.academyv2.mereka.io`
2. Navigate to **Content Libraries** in the main menu
3. Click **New Library**
4. Fill in library details:
   - **Organization**: Select your organization (determines access scope)
   - **Library Slug**: URL-safe identifier (e.g., `compliance-2024`)
   - **Title**: Display name (e.g., "Compliance Training Library 2024")
   - **Description**: Purpose and contents
   - **License**: Content license type (default: All Rights Reserved)
5. Click **Create** to initialize the library
6. Verify library appears in your library list with `has_unpublished_changes: false`

### Acceptance
- Library is created with unique `library_key` in format `lib:{org}:{slug}`
- Library is visible only to users in the same organization
- Library has no components initially
- Library can be opened in the authoring MFE

---

## Adding Components to a Library

### Procedure
1. Open the library in Studio's authoring interface
2. Click **Add Component** in the library editor
3. Select component type:
   - **HTML**: Text, images, formatted content
   - **Problem**: Multiple choice, text input, checkboxes
   - **Video**: Video player with YouTube/Wistia/uploaded files
   - **ORA (Open Response Assessment)**: Peer-graded assignments
4. Configure the component in the Studio editor
5. Save the component (status: **draft**)
6. Verify component appears in library component list

### Acceptance
- Component has unique `usage_key` within library namespace
- Component is editable by library authors
- Component is NOT yet visible to courses (draft state)
- Library shows `has_unpublished_changes: true`

---

## Publishing Library Changes

### Procedure
1. Review all draft changes in the library
2. Click **Publish** button in library header
3. Optionally add a change summary (e.g., "Added Q2 2024 compliance modules")
4. Confirm publish action
5. Verify publish completes:
   - `has_unpublished_changes` resets to `false`
   - All components show **published** status
   - Timestamp and publisher username are recorded

### Acceptance
- All draft changes are committed to Blockstore
- Courses can now reference the published components
- Version history includes new commit
- No further changes until next edit

---

## Embedding Library Content in Courses

### Procedure
1. Open a course unit in Studio
2. Click **Add New Component** → **Advanced** → **Library Content**
3. Configure the library content block:
   - **Library**: Select source library from dropdown
   - **Count**: Number of components to display (randomized mode)
   - **Problem Type Filter**: Optionally filter by component type
4. Save the course unit
5. Preview the course to verify library components render
6. Publish the course unit

### Acceptance
- Library content block displays components from the selected library
- Randomized selection (if configured) shows different components per learner
- Library components render correctly in LMS learner view
- Course sync status shows "up to date" with library

---

## Syncing Library Updates to Courses

### Procedure
1. Open a course that references a library in Studio
2. Navigate to the unit containing the library content block
3. Check for sync notification: "Newer version available"
4. Click **Sync from Library** button
5. Review changes that will be pulled from library
6. Confirm sync action
7. Verify updated components display in course preview

### Acceptance
- Course receives latest published library components
- Sync does NOT happen automatically (opt-in update model)
- Course version increments after sync
- Learners see updated content after course republish

---

## Managing Library Permissions

### Procedure
1. Open the library in Studio
2. Navigate to **Settings** → **Team**
3. Add a user:
   - **Email**: User's email address
   - **Role**: Admin | Author | Reader
4. Click **Add User**
5. Verify user appears in team member list
6. To revoke access, click **Remove** next to user

### Acceptance
- Users with Library Admin role can edit, publish, manage team
- Users with Library Author role can edit and publish (if allowed)
- Users with Library Reader role can view and reference, not edit
- Changes are logged for audit

---

## Troubleshooting

### Issue: Library Not Visible in Studio
**Symptoms**: Library exists but doesn't appear in user's library list

**Diagnosis**:
```bash
# Check library organization membership
kubectl exec -n mereka-lms -l app.kubernetes.io/name=lms -- \
  python manage.py lms shell -c "
from openedx.core.djangoapps.content_libraries.models import ContentLibrary
lib = ContentLibrary.objects.get(library_key='lib:ORG:SLUG')
print(f'Org: {lib.org}')
"
```

**Resolution**:
- Verify user is member of the library's organization
- Add user to organization via Django admin: `/admin/organizations/organization/`
- Grant library-specific access via library team settings

### Issue: Components Not Syncing to Course
**Symptoms**: Library content block shows "out of sync" even after sync action

**Diagnosis**:
- Check if library has unpublished changes (`has_unpublished_changes: true`)
- Verify course is not in draft state (publish course unit)

**Resolution**:
1. Publish library changes first
2. Then sync from library in course
3. Publish course unit to make changes visible to learners

### Issue: Blockstore Bundle Errors
**Symptoms**: "Unable to save component" error in Studio

**Diagnosis**:
```bash
# Check Blockstore backend storage
kubectl logs -n mereka-lms -l app.kubernetes.io/name=cms --tail=100 | grep -i blockstore
```

**Resolution**:
- Verify Google Cloud Storage bucket is accessible
- Check `BLOCKSTORE_BUNDLE_STORAGE` settings in CMS config
- Verify service account has `storage.objects.create` permission

---

## Related Documentation
- **Spec**: `specs/content-libraries-v2_spec.md`
- **Architecture**: `docs/architecture/content-libraries-overview.md`
- **General Troubleshooting**: `docs/operations/TROUBLESHOOTING.md`
