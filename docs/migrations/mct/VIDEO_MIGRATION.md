# MCT Video Migration to Mux

**Last Updated:** 2025-12-29 (14:58 UTC+8)
**Status:** ✅ COMPLETE - All 503 videos uploaded to Mux AND connected to Open edX

---

## Summary

| Metric | Count |
|--------|-------|
| Total Videos | 503 |
| Videos with Captions | 34 |
| Categories with Videos | 19 |
| Estimated Storage (Mux) | ~1,000-1,500 minutes |
| Estimated Monthly Cost | ~$3-5/month (with free tier) |

---

## Video Distribution by Category

| Category | Videos |
|----------|--------|
| Basic Microsoft | 135 |
| [VN] Mastering Digital Tools | 89 |
| Digital Literacy | 69 |
| X - Productivity with Microsoft 365 (Bahasa) | 25 |
| Mobile Literacy | 21 |
| Data Analytics | 20 |
| AI Fluency | 20 |
| Project Management | 19 |
| Speak with Impact | 15 |
| Employability | 14 |
| Personal Branding (ENG & IND) | 26 |
| Become an Entrepreneur | 11 |
| Green Jobs | 10 |
| Personal Finance | 9 |
| Soft Skills | 7 |
| Climate Education | 7 |
| Content Creation | 5 |
| Personal Well-being | 1 |

---

## Prerequisites

### 1. Mux API Credentials

You need to create Mux API credentials:

1. Log in to [Mux Dashboard](https://dashboard.mux.com)
2. Go to **Settings > API Access Tokens**
3. Create a new token with **Mux Video** permissions
4. Copy:
   - **Token ID** (e.g., `12345678-abcd-1234-efgh-567890abcdef`)
   - **Token Secret** (e.g., `a1b2c3d4e5f6...long-string...`)

### 2. Mux Environment ID (optional)

If using multiple environments:
- Environment ID: `d2pf0l73ablr4ghl1b607jpa2`

---

## Migration Steps

### Step 1: Re-export MCT Data (Fresh URLs)

MCT video URLs use Azure SAS tokens that expire after 6 hours. Before uploading to Mux, re-export to get fresh URLs:

```bash
cd /home/dev/bbi-meta/mereka-lms

MCT_BASE_URL="mctindonesia.azurewebsites.net" \
MCT_CLIENT_ID="caa4dce3-e49c-4c09-9160-031d51bfd2a9" \
MCT_CLIENT_SECRET="Mwo8Q~it.mHuXlwAKG4DPIq-~IuXMzuqkASfZcfh" \
MCT_TENANT_ID="b1aab053-6242-46ec-9cf8-bd02e63dd2da" \
MCT_API_URI="api://bf8331fd-17ed-4bcf-af5f-599db14ff4f4" \
node scripts/migrations/mct/mct-export.mjs --resources courses --force
```

### Step 2: Extract Video Information

```bash
node scripts/migrations/mct/extract_videos.mjs
```

Output: `exports/mct/videos_for_mux.json`

### Step 3: Upload to Mux

```bash
# Activate venv
source .venv/bin/activate

# Set Mux credentials
export MUX_TOKEN_ID="your-token-id"
export MUX_TOKEN_SECRET="your-token-secret"

# Dry run first
python scripts/migrations/mct/upload_videos_to_mux.py --dry-run

# Upload all videos
python scripts/migrations/mct/upload_videos_to_mux.py

# Or upload by category
python scripts/migrations/mct/upload_videos_to_mux.py --category "AI Fluency"

# Or with limit
python scripts/migrations/mct/upload_videos_to_mux.py --limit 10
```

### Step 4: Update Open edX Courses

After uploading, create a mapping file:

```bash
python scripts/migrations/mct/update_openedx_videos.py \
    --results-file exports/mct/mux_upload_results.json \
    --output exports/mct/openedx_video_mapping.json
```

Then update courses in Open edX Studio, or use the bulk update script inside the CMS pod.

---

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `mct-export.mjs` | Export MCT data with fresh video URLs |
| `extract_videos.mjs` | Extract video info to JSON for Mux |
| `upload_videos_to_mux.py` | Upload videos to Mux from URLs |
| `update_openedx_videos.py` | Create Open edX video mappings |

---

## Important Notes

### SAS Token Expiry

MCT video URLs include Azure SAS tokens that expire after 6 hours:
- `se=2025-12-29T11:03:34Z` - Expiry time (UTC)
- `st=2025-12-29T05:03:34Z` - Start time (UTC)

If uploads fail with 403 errors, re-run the MCT export to get fresh URLs.

### Mux URL Format

After upload, videos are available at:
- **Stream URL:** `https://stream.mux.com/{PLAYBACK_ID}`
- **HLS URL:** `https://stream.mux.com/{PLAYBACK_ID}.m3u8`
- **Thumbnail:** `https://image.mux.com/{PLAYBACK_ID}/thumbnail.jpg`

### Captions/Subtitles

34 videos have embedded caption tracks (VTT format). The upload script automatically includes these with the Mux asset.

---

## Cost Estimate (Mux)

Based on 503 videos (~5 min average = 2,515 minutes):

| Cost Type | Rate | Estimated Cost |
|-----------|------|----------------|
| Encoding (Basic) | FREE | $0 |
| Storage (Month 1-3) | $0.003/min/mo | $7.55/mo |
| Storage (After 90 days) | $0.0012/min/mo | $3.02/mo |
| Delivery | $0.00096/min | FREE (under 100K min/mo) |

**Estimated Annual Cost:** $50-60 (mostly storage)

---

## Troubleshooting

### "SAS token expired" errors
Re-run the MCT export to get fresh URLs. SAS tokens are valid for 6 hours.

### Mux upload failures
- Check MUX_TOKEN_ID and MUX_TOKEN_SECRET are set
- Verify source URLs are accessible (curl test)
- Check Mux dashboard for error details

### Rate limiting
The script includes 0.25s delays between uploads. Mux allows 5 requests/second.

---

## Files

| File | Description |
|------|-------------|
| `exports/mct/videos_for_mux.json` | Extracted video data with URLs |
| `exports/mct/mux_upload_results.json` | Upload results with Mux asset IDs |
| `exports/mct/openedx_video_mapping.json` | Mapping for Open edX updates |

---

## ✅ Completed Steps

1. ✅ **Mux API credentials** configured in `.env.mux`
2. ✅ **All 503 videos uploaded** to Mux
3. ✅ **Videos verified** in Mux dashboard with proper titles
4. ✅ **30 course packages rebuilt** with Mux Video XBlocks
5. ✅ **Courses re-imported** to Open edX with Mux HLS URLs

### Open edX Integration (Completed 2025-12-29)

The courses now contain proper Video XBlocks pointing to Mux HLS streams:

```xml
<video url_name="video_2257" display_name="What is artificial intelligence?">
  <source src="https://stream.mux.com/Cdo2u9VYeGjR9iFM500aW019yFB3z7UlHiouM4y023O6Q4.m3u8"/>
</video>
```

**Scripts Used:**
- `scripts/migrations/mct/create_video_mapping.py` - Maps MCT lessons to Mux playback IDs
- `scripts/migrations/mct/build_courses_with_mux.py` - Builds OLX packages with Video XBlocks
- `scripts/migrations/mct/fix_mux_titles.py` - Updates Mux asset titles via API

**Files Generated:**
- `exports/mct/video_mapping_openedx.json` - Complete mapping of lessons to Mux URLs
- `var/migrations/mct/course_packages_mux/` - 30 OLX packages with Mux videos
