#!/usr/bin/env node
/**
 * Export course/quiz completion data from Kajabi using contact tags.
 *
 * Kajabi's API has no completions endpoint, but lesson automations tag contacts
 * on completion (e.g. "F101 - Course Completed", "MYFC - Quiz 1 Completed").
 * This script:
 *   1. Fetches all contact_tags
 *   2. Identifies completion-related tags (matching patterns like "Completed", "completed")
 *   3. For each completion tag, fetches all contacts with that tag
 *   4. Writes completions.ndjson with {email, name, tag, course_prefix, type, completed_via_tag}
 *
 * Usage:
 *   KAJABI_CLIENT_ID=... KAJABI_CLIENT_SECRET=... \
 *   node scripts/migrations/kajabi/kajabi-export-completions.mjs --out exports/kajabi
 *
 * Or via Infisical:
 *   infisical run --env=prod --path=/mereka-lms/kajabi -- \
 *     node scripts/migrations/kajabi/kajabi-export-completions.mjs --out exports/kajabi
 */

import fs from "node:fs";
import path from "node:path";

const API = "https://api.kajabi.com";
const CLIENT_ID = process.env.KAJABI_CLIENT_ID;
const CLIENT_SECRET = process.env.KAJABI_CLIENT_SECRET;
const SITE_ID = process.env.KAJABI_SITE_ID;

if (!CLIENT_ID || !CLIENT_SECRET) {
  console.error("Missing KAJABI_CLIENT_ID or KAJABI_CLIENT_SECRET");
  process.exit(1);
}

const args = process.argv.slice(2);
let OUT_DIR = "./exports/kajabi";
for (let i = 0; i < args.length; i++) {
  if (args[i] === "--out" && args[i + 1]) OUT_DIR = args[i + 1];
}
OUT_DIR = path.resolve(OUT_DIR);
fs.mkdirSync(OUT_DIR, { recursive: true });

const PAGE_SIZE = 100;
const MAX_ATTEMPTS = 3;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function jfetch(url, opts = {}, attempt = 1) {
  const res = await fetch(url, opts);
  if (res.status === 429 || res.status >= 500) {
    if (attempt >= MAX_ATTEMPTS) {
      throw new Error(`HTTP ${res.status} for ${url} after ${attempt} attempts`);
    }
    const retryAfter = parseInt(res.headers.get("Retry-After") || "0", 10);
    const delay = retryAfter > 0 ? retryAfter * 1000 : Math.min(30000, 500 * 2 ** attempt);
    console.warn(`  Rate limited, retrying in ${delay}ms...`);
    await sleep(delay);
    return jfetch(url, opts, attempt + 1);
  }
  if (!res.ok) throw new Error(`HTTP ${res.status} for ${url}`);
  return res.json();
}

async function getToken() {
  const body = new URLSearchParams({
    client_id: CLIENT_ID, client_secret: CLIENT_SECRET,
    grant_type: "client_credentials",
  });
  const json = await jfetch(`${API}/v1/oauth/token`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  return json.access_token;
}

function classifyTag(tagName) {
  const lower = tagName.toLowerCase();
  if (lower.includes("course completed") || lower.endsWith("-completed")) {
    return "course_completed";
  }
  if (lower.includes("quiz") && lower.includes("completed")) {
    return "quiz_completed";
  }
  if (lower.includes("cert")) {
    return "certificate";
  }
  if (lower.includes("onboarded")) {
    return "onboarded";
  }
  if (lower.includes("started")) {
    return "started";
  }
  return null; // Not a completion/lifecycle tag
}

function extractCoursePrefix(tagName) {
  // "F101 - Course Completed" → "F101"
  // "elevate-ai-1-completed" → "elevate-ai-1"
  const dashMatch = tagName.match(/^(.+?)\s*-\s*(Course Completed|Started|Onboarded|Quiz|Granted)/i);
  if (dashMatch) return dashMatch[1].trim();
  const suffixMatch = tagName.match(/^(.+)-completed$/i);
  if (suffixMatch) return suffixMatch[1].trim();
  return tagName;
}

(async () => {
  console.log("Authenticating with Kajabi...");
  const token = await getToken();

  // 1. Fetch all contact tags
  console.log("\nFetching contact tags...");
  const allTags = [];
  let page = 1;
  while (true) {
    const params = new URLSearchParams({ "page[number]": page, "page[size]": PAGE_SIZE });
    if (SITE_ID) params.set("filter[site_id]", SITE_ID);
    const json = await jfetch(`${API}/v1/contact_tags?${params}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!json.data?.length) break;
    allTags.push(...json.data);
    if (!json.links?.next) break;
    page++;
  }
  console.log(`Found ${allTags.length} tags total`);

  // 2. Identify completion/lifecycle tags
  const completionTags = [];
  for (const tag of allTags) {
    const name = tag.attributes?.name || "";
    const type = classifyTag(name);
    if (type) {
      completionTags.push({ id: tag.id, name, type, prefix: extractCoursePrefix(name) });
    }
  }
  console.log(`\nIdentified ${completionTags.length} completion/lifecycle tags:`);
  for (const t of completionTags) {
    console.log(`  [${t.type}] "${t.name}" (prefix: ${t.prefix})`);
  }

  // 3. For each tag, fetch contacts
  const outFile = path.join(OUT_DIR, "completions.ndjson");
  fs.writeFileSync(outFile, "");
  let totalRecords = 0;

  for (const tag of completionTags) {
    console.log(`\nFetching contacts for tag "${tag.name}" (id: ${tag.id})...`);
    let tagPage = 1;
    let tagTotal = 0;

    while (true) {
      const params = new URLSearchParams({
        "page[number]": tagPage,
        "page[size]": PAGE_SIZE,
        "filter[tag_id]": tag.id,
      });
      if (SITE_ID) params.set("filter[site_id]", SITE_ID);

      let json;
      try {
        json = await jfetch(`${API}/v1/contacts?${params}`, {
          headers: { Authorization: `Bearer ${token}` },
        });
      } catch (err) {
        console.error(`  Error on page ${tagPage}: ${err.message}`);
        break;
      }

      if (!json.data?.length) break;

      const records = json.data.map((contact) => ({
        email: contact.attributes?.email || "",
        name: contact.attributes?.name || "",
        contact_id: contact.id,
        tag_id: tag.id,
        tag_name: tag.name,
        tag_type: tag.type,
        course_prefix: tag.prefix,
      }));

      const lines = records.map((r) => JSON.stringify(r)).join("\n") + "\n";
      fs.appendFileSync(outFile, lines);
      tagTotal += records.length;
      totalRecords += records.length;

      if (tagPage % 10 === 0 || !json.links?.next) {
        console.log(`  "${tag.name}" page ${tagPage} → ${tagTotal} contacts so far`);
      }

      if (!json.links?.next) break;
      tagPage++;
      await sleep(200); // Be gentle with rate limits
    }

    console.log(`  "${tag.name}": ${tagTotal} contacts`);
  }

  // 4. Summary
  console.log(`\n=== Summary ===`);
  console.log(`Total completion/lifecycle records: ${totalRecords}`);
  console.log(`Tags processed: ${completionTags.length}`);
  console.log(`Output: ${outFile}`);
  console.log(`\nCompletion export finished ✅`);
})();
