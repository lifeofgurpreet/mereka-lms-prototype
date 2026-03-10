# Kajabi Lesson Content Issue
_Audience: Platform Eng • Owner: Migration Squad • Last verified: 2025-08-18_

## Problem

All lessons imported from Kajabi are showing as **placeholders** with the message:
> "This lesson was migrated from Kajabi. Replace this placeholder with real content."

## Root Cause

The **Kajabi Public API does not expose lesson content/body text**. The API only provides:
- Lesson metadata (title, position, status, publishing_option)
- Lesson relationships (module, media)
- Media references (videos, files)

**No lesson content/body/html/text is available** through the Public API.

## Evidence

### What the API Provides

From `exports/kajabi/structure/lessons.ndjson`:
```json
{
  "lesson": {
    "attributes": {
      "title": "1.1 Educator Guide",
      "position": 0,
      "status": "ready",
      "publishing_option": "published"
    }
  }
}
```

**No content fields exist** - only metadata.

### Current Implementation

The `html_block_for_lesson()` function in `build_course_packages.py` (line 112) creates placeholders:

```python
rows = [
    "<p><em>This lesson was migrated from Kajabi. Replace this placeholder with real content.</em></p>",
    "<ul>",
]
```

This is correct behavior given the API limitations.

## Solutions

### Option 1: Manual Content Migration (Recommended for Now)

1. **Export lesson content manually** from Kajabi UI
2. **Update course packages** with real content
3. **Re-import courses** into Open edX

### Option 2: Web Scraping (Not Recommended)

- Scrape lesson content from Kajabi web interface
- Requires authentication and may violate ToS
- Fragile and maintenance-heavy

### Option 3: Kajabi Private API (If Available)

- Check if Kajabi offers a private API with lesson content
- May require enterprise plan or special access
- Contact Kajabi support

### Option 4: Hybrid Approach

1. Keep current structure (modules, lessons, media references)
2. Manually add content to lessons in Open edX Studio
3. Use media references to link to Kajabi-hosted videos/files

## Impact

- ✅ **Course structure** is correct (modules, lessons, hierarchy)
- ✅ **Lesson metadata** is correct (titles, positions, status)
- ✅ **Media references** are preserved (videos, files)
- ❌ **Lesson content** is missing (body text, HTML, descriptions)

## Next Steps

1. **Immediate:** Document this limitation in migration notes
2. **Short-term:** Create a process for manual content migration
3. **Long-term:** Explore Kajabi API alternatives or content export options

## Related Documentation

- `docs/reference/migrations/kajabi/KAJABI_MIGRATION_NOTES.md` - Line 31-33 documents missing content
- `scripts/migrations/kajabi/build_course_packages.py` - Line 95-121 shows placeholder generation

---

**Status:** Known limitation - Kajabi Public API doesn't provide lesson content  
**Workaround:** Manual content migration required  
**Priority:** Medium (structure is correct, content needs manual addition)
