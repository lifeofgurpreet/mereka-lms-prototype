#!/usr/bin/env node

/**
 * Kajabi Public API exporter (Node 20+)
 *
 * Supports exporting individual resources, paging through large collections,
 * and writing newline-delimited JSON files so we can resume and process data incrementally.
 *
 * Usage examples:
 *   node scripts/migrations/kajabi/kajabi-export.mjs --resources contacts,customers
 *   node scripts/migrations/kajabi/kajabi-export.mjs --resources courses --site 2147565329 --start-page 1 --end-page 5
 *   node scripts/migrations/kajabi/kajabi-export.mjs --resources courses --skip-course-details
 *
 * Environment variables (fallbacks):
 *   KAJABI_CLIENT_ID, KAJABI_CLIENT_SECRET  – required
 *   KAJABI_SITE_ID                          – optional (pass via --site instead if you prefer)
 *   WEBHOOK_TARGET_URL                      – optional, auto-creates webhooks when --ensure-webhooks flag is used
 */

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const API = "https://api.kajabi.com";
const HOOKS_BASE = `${API}/api/v1`;

const DEFAULT_RESOURCES = [
  "contacts",
  "customers",
  "contact_tags",
  "custom_fields",
  "offers",
  "products",
  "courses",
  "purchases",
  "transactions",
  "orders",
  "order_items",
  "forms",
  "form_submissions",
];

// -------- argument parsing -------------------------------------------------

const argv = process.argv.slice(2);
const options = parseArgs(argv);

const KAJABI_CLIENT_ID = options["client-id"] || process.env.KAJABI_CLIENT_ID;
const KAJABI_CLIENT_SECRET =
  options["client-secret"] || process.env.KAJABI_CLIENT_SECRET;
const KAJABI_SITE_ID =
  options.site || process.env.KAJABI_SITE_ID || undefined;
const WEBHOOK_TARGET_URL =
  options["webhook-target"] || process.env.WEBHOOK_TARGET_URL;

if (!KAJABI_CLIENT_ID || !KAJABI_CLIENT_SECRET) {
  console.error("Missing KAJABI_CLIENT_ID or KAJABI_CLIENT_SECRET");
  process.exit(1);
}

const OUT_DIR = path.resolve(options.out || "./exports/kajabi");
const PAGE_SIZE = Number(options["page-size"] || 100);
const START_PAGE = Number(options["start-page"] || 1);
const END_PAGE =
  options["end-page"] !== undefined ? Number(options["end-page"]) : undefined;
const SKIP_COURSE_DETAILS = Boolean(options["skip-course-details"]);
const RESOURCES = (options.resources
  ? options.resources.split(",")
  : DEFAULT_RESOURCES
).map((r) => r.trim()).filter(Boolean);

fs.mkdirSync(OUT_DIR, { recursive: true });

// -------- HTTP helpers -----------------------------------------------------

const MAX_ATTEMPTS = 3;

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function jfetch(url, opts = {}, attempt = 1) {
  const res = await fetch(url, opts);
  if (res.status === 429 || res.status >= 500) {
    if (attempt >= MAX_ATTEMPTS) {
      const text = await res.text().catch(() => "");
      throw new Error(
        `Exceeded retries (${attempt}) for ${url} [status ${res.status}]\n${text}`
      );
    }
    const retryAfter = parseInt(res.headers.get("Retry-After") || "0", 10);
    const delay =
      retryAfter > 0 ? retryAfter * 1000 : Math.min(30000, 500 * 2 ** attempt);
    console.warn(`Retrying ${url} in ${delay}ms (status ${res.status})`);
    await sleep(delay);
    return jfetch(url, opts, attempt + 1);
  }
  if (!res.ok) {
    const text = await res.text().catch(() => "");
    throw new Error(`HTTP ${res.status} for ${url}\n${text}`);
  }
  return res.json();
}

async function getToken() {
  const body = new URLSearchParams({
    client_id: KAJABI_CLIENT_ID,
    client_secret: KAJABI_CLIENT_SECRET,
    grant_type: "client_credentials",
  });
  const json = await jfetch(`${API}/v1/oauth/token`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  return json.access_token;
}

async function fetchPage(token, resource, params, page) {
  const usp = new URLSearchParams({
    ...params,
    "page[number]": page,
    "page[size]": PAGE_SIZE,
  });
  const url = `${API}/v1/${resource}?${usp.toString()}`;
  const json = await jfetch(url, {
    headers: { Authorization: `Bearer ${token}` },
  });
  const data = json.data || [];
  const next = json.links?.next;
  return { data, next };
}

function appendNdjson(filepath, records) {
  if (!records || records.length === 0) return;
  const lines = records.map((item) => JSON.stringify(item)).join("\n") + "\n";
  fs.appendFileSync(filepath, lines);
}

function resetFile(filepath) {
  fs.writeFileSync(filepath, "");
}

// -------- export routines --------------------------------------------------

async function exportCollection(token, resource, params = {}, filename) {
  const file = path.join(OUT_DIR, filename || `${resource}.ndjson`);
  resetFile(file);
  let page = START_PAGE;
  let total = 0;
  while (true) {
    if (END_PAGE && page > END_PAGE) break;
    const { data, next } = await fetchPage(token, resource, params, page);
    if (!data.length) {
      console.log(`[${resource}] page ${page} returned 0 records, stopping.`);
      break;
    }
    appendNdjson(file, data);
    total += data.length;
    console.log(`[${resource}] page ${page} → ${data.length} records (total ${total})`);
    if (!next) break;
    page += 1;
  }
  return total;
}

async function exportCourses(token, params) {
  const indexFile = path.join(OUT_DIR, "courses_index.ndjson");
  const detailFile = path.join(OUT_DIR, "courses_full.ndjson");
  const errorFile = path.join(OUT_DIR, "courses_errors.ndjson");
  resetFile(indexFile);
  if (!SKIP_COURSE_DETAILS) resetFile(detailFile);
  resetFile(errorFile);

  let page = START_PAGE;
  let indexCount = 0;
  let detailCount = 0;

  while (true) {
    if (END_PAGE && page > END_PAGE) break;
    const { data, next } = await fetchPage(token, "courses", params, page);
    if (!data.length) {
      console.log(`[courses] page ${page} returned 0 records, stopping.`);
      break;
    }
    appendNdjson(indexFile, data);
    indexCount += data.length;
    console.log(`[courses] page ${page} → ${data.length} records (total ${indexCount})`);

    if (!SKIP_COURSE_DETAILS) {
      for (const course of data) {
        try {
          const detail = await getCourseDetail(token, course.id, params);
          appendNdjson(detailFile, [detail]);
          detailCount += 1;
        } catch (err) {
          console.error(
            `Failed to expand course ${course.id}: ${err.message.split("\n")[0]}`
          );
          appendNdjson(errorFile, [
            { course_id: course.id, error: err.message, timestamp: new Date().toISOString() },
          ]);
        }
      }
    }

    if (!next) break;
    page += 1;
  }

  console.log(
    `[courses] index total=${indexCount}` +
      (SKIP_COURSE_DETAILS ? "" : `, detailed=${detailCount}`)
  );
}

async function getCourseDetail(token, id, params) {
  const includeParams = {
    ...params,
    include: "modules,lessons,lessons.media,offers",
  };
  try {
    const detailed = await fetchCourse(token, id, includeParams);
    return detailed;
  } catch (err) {
    console.warn(
      `Falling back to basic course fetch for ${id}: ${err.message.split("\n")[0]}`
    );
    const basic = await fetchCourse(token, id, params);
    return basic;
  }
}

async function fetchCourse(token, id, params) {
  const usp = new URLSearchParams(params);
  const url = `${API}/v1/courses/${id}?${usp.toString()}`;
  const json = await jfetch(url, {
    headers: { Authorization: `Bearer ${token}` },
  });
  return json;
}

async function exportForms(token, params) {
  const file = path.join(OUT_DIR, "forms.ndjson");
  resetFile(file);
  const formIds = [];
  let page = START_PAGE;
  while (true) {
    if (END_PAGE && page > END_PAGE) break;
    const { data, next } = await fetchPage(token, "forms", params, page);
    if (!data.length) break;
    appendNdjson(file, data);
    data.forEach((form) => formIds.push(form.id));
    console.log(`[forms] page ${page} → ${data.length} records (total ${formIds.length})`);
    if (!next) break;
    page += 1;
  }
  return formIds;
}

async function exportFormSubmissions(token, params, formIds) {
  const file = path.join(OUT_DIR, "form_submissions.ndjson");
  resetFile(file);
  let total = 0;
  for (const formId of formIds) {
    let page = START_PAGE;
    while (true) {
      if (END_PAGE && page > END_PAGE) break;
      const filters = {
        ...params,
        "filter[form_id]": formId,
      };
      const { data, next } = await fetchPage(
        token,
        "form_submissions",
        filters,
        page
      );
      if (!data.length) break;
      const records = data.map((submission) => ({
        form_id: formId,
        submission,
      }));
      appendNdjson(file, records);
      total += records.length;
      console.log(
        `[form_submissions] form ${formId} page ${page} → ${records.length} records (total ${total})`
      );
      if (!next) break;
      page += 1;
    }
  }
}

async function ensureWebhook(token, event, siteId, targetUrl) {
  const listUrl = `${HOOKS_BASE}/hooks?filter[event_eq]=${encodeURIComponent(
    event
  )}`;
  const list = await jfetch(listUrl, {
    headers: { Authorization: `Bearer ${token}` },
  });
  const existing = (list.data || []).find(
    (h) => h.attributes?.target_url === targetUrl
  );
  if (existing) {
    return `exists:${event}`;
  }

  const payload = {
    data: {
      type: "hooks",
      attributes: { event, target_url: targetUrl },
      relationships: siteId
        ? { site: { data: { id: String(siteId), type: "sites" } } }
        : undefined,
    },
  };
  const created = await jfetch(`${HOOKS_BASE}/hooks`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/vnd.api+json",
    },
    body: JSON.stringify(payload),
  });
  return created?.data?.id || `created:${event}`;
}

// -------- main execution ---------------------------------------------------

(async () => {
  console.log("Authenticating with Kajabi…");
  const token = await getToken();

  const baseParams = {};
  if (KAJABI_SITE_ID) baseParams["filter[site_id]"] = KAJABI_SITE_ID;

  const completedForms = new Set();

  for (const resource of RESOURCES) {
    switch (resource) {
      case "contacts":
      case "customers":
      case "contact_tags":
      case "custom_fields":
      case "offers":
      case "products":
      case "purchases":
      case "transactions":
      case "orders":
      case "order_items":
        await exportCollection(token, resource, baseParams);
        break;

      case "courses":
        await exportCourses(token, baseParams);
        break;

      case "forms": {
        const ids = await exportForms(token, baseParams);
        ids.forEach((id) => completedForms.add(id));
        break;
      }

      case "form_submissions": {
        let ids = Array.from(completedForms);
        if (!ids.length) {
          // Ensure we have the forms exported first
          console.log("[form_submissions] no form cache found, exporting forms first.");
          ids = await exportForms(token, baseParams);
        }
        await exportFormSubmissions(token, baseParams, ids);
        break;
      }

      default:
        console.warn(`Unknown resource "${resource}" – skipping.`);
    }
  }

  if (options["ensure-webhooks"] && WEBHOOK_TARGET_URL) {
    console.log("Ensuring webhook subscriptions…");
    const events = [
      "purchase",
      "payment_succeeded",
      "order_created",
      "form_submission",
      "tag_added",
      "tag_removed",
    ];
    for (const ev of events) {
      try {
        const status = await ensureWebhook(
          token,
          ev,
          KAJABI_SITE_ID,
          WEBHOOK_TARGET_URL
        );
        console.log(`  ${ev}: ${status}`);
        await sleep(150);
      } catch (err) {
        console.error(`  ${ev}: ${err.message}`);
      }
    }
  }

  console.log("Kajabi export finished ✅");
})();

// -------- utility functions ------------------------------------------------

function parseArgs(args) {
  const out = {};
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (!arg.startsWith("--")) continue;
    const key = arg.slice(2);
    const next = args[i + 1];
    if (next && !next.startsWith("--")) {
      out[key] = next;
      i += 1;
    } else {
      out[key] = true;
    }
  }
  return out;
}
