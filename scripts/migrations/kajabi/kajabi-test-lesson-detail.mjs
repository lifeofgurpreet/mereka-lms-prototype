#!/usr/bin/env node
/**
 * Test script to verify what fields are available from Kajabi's lesson detail endpoint.
 * 
 * Usage:
 *   node scripts/migrations/kajabi/kajabi-test-lesson-detail.mjs --lesson-id 2192178188
 */

import process from "node:process";

const API = "https://api.kajabi.com";
const CLIENT_ID = process.env.KAJABI_CLIENT_ID;
const CLIENT_SECRET = process.env.KAJABI_CLIENT_SECRET;

if (!CLIENT_ID || !CLIENT_SECRET) {
  console.error("Missing KAJABI_CLIENT_ID or KAJABI_CLIENT_SECRET");
  process.exit(1);
}

const args = parseArgs(process.argv.slice(2));
const LESSON_ID = args["lesson-id"] || args.l;

if (!LESSON_ID) {
  console.error("Usage: node kajabi-test-lesson-detail.mjs --lesson-id <lesson_id>");
  process.exit(1);
}

async function getToken() {
  const body = new URLSearchParams({
    client_id: CLIENT_ID,
    client_secret: CLIENT_SECRET,
    grant_type: "client_credentials",
  });
  const res = await fetch(`${API}/v1/oauth/token`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  if (!res.ok) {
    throw new Error(`Failed to get token: ${res.status} ${await res.text()}`);
  }
  const json = await res.json();
  return json.access_token;
}

async function fetchLessonDetail(token, lessonId) {
  // Try different include parameters to see what's available
  const includes = [
    "", // no includes
    "media",
    "media,downloads",
    "media,downloads,content_blocks",
  ];

  const results = {};
  
  for (const include of includes) {
    const params = new URLSearchParams();
    if (include) params.set("include", include);
    const url = `${API}/v1/lessons/${lessonId}?${params.toString()}`;
    
    try {
      const res = await fetch(url, {
        headers: { Authorization: `Bearer ${token}` },
      });
      
      if (!res.ok) {
        results[include || "none"] = {
          error: `HTTP ${res.status}`,
          text: await res.text().catch(() => ""),
        };
        continue;
      }
      
      const json = await res.json();
      results[include || "none"] = json;
    } catch (err) {
      results[include || "none"] = { error: err.message };
    }
  }
  
  return results;
}

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (!arg.startsWith("--")) continue;
    const key = arg.slice(2).replace(/-/g, "-");
    const next = argv[i + 1];
    if (next && !next.startsWith("--")) {
      out[key] = next;
      i += 1;
    } else {
      out[key] = true;
    }
  }
  return out;
}

(async () => {
  console.log(`Fetching lesson detail for lesson ID: ${LESSON_ID}`);
  const token = await getToken();
  const results = await fetchLessonDetail(token, LESSON_ID);
  
  console.log("\n=== Results ===\n");
  console.log(JSON.stringify(results, null, 2));
  
  // Extract key fields for easy inspection
  console.log("\n=== Key Fields Summary ===\n");
  for (const [include, data] of Object.entries(results)) {
    if (data.error) {
      console.log(`Include "${include}": ERROR - ${data.error}`);
      continue;
    }
    
    const lesson = data.data;
    if (lesson) {
      const attrs = lesson.attributes || {};
      console.log(`Include "${include}":`);
      console.log(`  - Title: ${attrs.title || "N/A"}`);
      console.log(`  - Body: ${attrs.body ? `${attrs.body.substring(0, 100)}...` : "N/A"}`);
      console.log(`  - Content HTML: ${attrs.content_html ? `${attrs.content_html.substring(0, 100)}...` : "N/A"}`);
      console.log(`  - Video URL: ${attrs.video_url || "N/A"}`);
      console.log(`  - Download URL: ${attrs.download_url || "N/A"}`);
      console.log(`  - Included resources: ${data.included ? data.included.map(i => i.type).join(", ") : "none"}`);
      console.log("");
    }
  }
})();




