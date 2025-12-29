#!/usr/bin/env node

/**
 * Fetches detailed course payloads (modules, lessons, media, offers) for a list
 * of course IDs in `courses_index.ndjson`. Supports chunking via --start/--end indexes.
 *
 * Usage:
 *   node tools/kajabi-course-details.mjs \
 *     --input exports/kajabi/courses_index.ndjson \
 *     --output exports/kajabi/courses_full.ndjson \
 *     --site 2147565329 \
 *     --start 1 \
 *     --end 50
 */

import fs from "node:fs";
import readline from "node:readline";

const args = parseArgs(process.argv.slice(2));

const INPUT = args.input || "exports/kajabi/courses_index.ndjson";
const OUTPUT = args.output || "exports/kajabi/courses_full.ndjson";
const ERROR_LOG = args.errors || "exports/kajabi/courses_errors.ndjson";
const START_INDEX = Number(args.start || 1);
const END_INDEX = args.end ? Number(args.end) : Infinity;
const SITE_ID = args.site || process.env.KAJABI_SITE_ID;
const DELAY_MS = Number(args.delay || 250);

const CLIENT_ID = args["client-id"] || process.env.KAJABI_CLIENT_ID;
const CLIENT_SECRET =
  args["client-secret"] || process.env.KAJABI_CLIENT_SECRET;

if (!CLIENT_ID || !CLIENT_SECRET) {
  console.error("Missing KAJABI_CLIENT_ID or KAJABI_CLIENT_SECRET");
  process.exit(1);
}

const API = "https://api.kajabi.com";
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
    client_id: CLIENT_ID,
    client_secret: CLIENT_SECRET,
    grant_type: "client_credentials",
  });
  const json = await jfetch(`${API}/v1/oauth/token`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  return json.access_token;
}

async function fetchCourse(token, id, includeDetails = false) {
  const params = new URLSearchParams();
  if (SITE_ID) params.append("filter[site_id]", SITE_ID);
  if (includeDetails) {
    params.append("include", "modules,lessons,lessons.media,offers");
  }
  const url = `${API}/v1/courses/${id}?${params.toString()}`;
  return jfetch(url, { headers: { Authorization: `Bearer ${token}` } });
}

async function fetchCourseWithFallback(token, id) {
  try {
    return await fetchCourse(token, id, true);
  } catch (err) {
    console.warn(
      `Falling back to basic course fetch for ${id}: ${err.message.split("\n")[0]}`
    );
    return fetchCourse(token, id, false);
  }
}

function appendLine(file, data) {
  fs.appendFileSync(file, JSON.stringify(data) + "\n");
}

(async () => {
  console.log(
    `Exporting course details from ${INPUT} (rows ${START_INDEX}..${END_INDEX})`
  );
  const token = await getToken();
  fs.writeFileSync(OUTPUT, "");
  fs.writeFileSync(ERROR_LOG, "");

  const rl = readline.createInterface({
    input: fs.createReadStream(INPUT),
    crlfDelay: Infinity,
  });

  let idx = 0;
  let exported = 0;
  for await (const line of rl) {
    if (!line.trim()) continue;
    idx += 1;
    if (idx < START_INDEX) continue;
    if (idx > END_INDEX) break;

    let course;
    try {
      course = JSON.parse(line);
    } catch (err) {
      appendLine(ERROR_LOG, {
        course_index: idx,
        error: `Parse error: ${err.message}`,
        raw: line,
      });
      continue;
    }

    const courseId = course.id || course.data?.id;
    if (!courseId) {
      appendLine(ERROR_LOG, {
        course_index: idx,
        error: "Missing course ID",
        raw: course,
      });
      continue;
    }

    try {
      const detail = await fetchCourseWithFallback(token, courseId);
      appendLine(OUTPUT, detail);
      exported += 1;
      if (DELAY_MS > 0) await sleep(DELAY_MS);
    } catch (err) {
      appendLine(ERROR_LOG, {
        course_index: idx,
        course_id: courseId,
        error: err.message,
      });
    }
  }

  console.log(`Wrote ${exported} course detail records to ${OUTPUT}`);
})();

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (!arg.startsWith("--")) continue;
    const key = arg.slice(2);
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
