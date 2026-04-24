#!/usr/bin/env node
import fs from "node:fs";
import readline from "node:readline";

const args = parseArgs(process.argv.slice(2));
const COURSES_FILE = args.input || "exports/kajabi/courses_index.ndjson";
const OUT_DIR = args.out || "exports/kajabi/structure";
const SITE_ID = args.site || process.env.KAJABI_SITE_ID;
const START = Number(args.start || 1);
const END = args.end ? Number(args.end) : Infinity;
const DELAY = Number(args.delay || 400);
const CLIENT_ID = args["client-id"] || process.env.KAJABI_CLIENT_ID;
const CLIENT_SECRET = args["client-secret"] || process.env.KAJABI_CLIENT_SECRET;

if (!CLIENT_ID || !CLIENT_SECRET) {
  console.error("Missing Kajabi client credentials.");
  process.exit(1);
}

const API = "https://api.kajabi.com";
const MAX_ATTEMPTS = 3;
fs.mkdirSync(OUT_DIR, { recursive: true });
const modulesFile = `${OUT_DIR}/modules.ndjson`;
const lessonsFile = `${OUT_DIR}/lessons.ndjson`;
const lessonDetailsFile = `${OUT_DIR}/lesson_details.ndjson`;
const mediaFile = `${OUT_DIR}/lesson_media.ndjson`;
const errorsFile = `${OUT_DIR}/errors.ndjson`;
fs.writeFileSync(modulesFile, "");
fs.writeFileSync(lessonsFile, "");
fs.writeFileSync(lessonDetailsFile, "");
fs.writeFileSync(mediaFile, "");
fs.writeFileSync(errorsFile, "");

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function jfetch(url, opts = {}, attempt = 1) {
  const res = await fetch(url, opts);
  if (res.status === 429 || res.status >= 500) {
    if (attempt >= MAX_ATTEMPTS) {
      const text = await res.text().catch(() => "");
      throw new Error(`HTTP ${res.status} for ${url}\n${text}`);
    }
    const retryAfter = parseInt(res.headers.get("Retry-After") || "0", 10);
    const delay = retryAfter > 0 ? retryAfter * 1000 : Math.min(30000, 500 * 2 ** attempt);
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

function appendLine(path, obj) {
  fs.appendFileSync(path, JSON.stringify(obj) + "\n");
}

function buildParams(extra = {}) {
  const params = new URLSearchParams(extra);
  if (SITE_ID) params.set("filter[site_id]", SITE_ID);
  return params.toString();
}

async function fetchCollection(token, url) {
  const items = [];
  let nextUrl = url;
  while (nextUrl) {
    const json = await jfetch(nextUrl, {
      headers: { Authorization: `Bearer ${token}` },
    });
    items.push(...(json.data || []));
    nextUrl = json.links?.next || null;
  }
  return items;
}

async function fetchCourseInclude(token, courseId, includeParam) {
  const params = buildParams({ include: includeParam });
  const url = `${API}/v1/courses/${courseId}?${params}`;
  const json = await jfetch(url, {
    headers: { Authorization: `Bearer ${token}` },
  });
  return json.included || [];
}

async function fetchCourseLessonMedia(token, courseId) {
  const params = buildParams({ include: "lessons.media" });
  const url = `${API}/v1/courses/${courseId}?${params}`;
  try {
    const json = await jfetch(url, {
      headers: { Authorization: `Bearer ${token}` },
    });
    return json.included || [];
  } catch (err) {
    return { error: err.message };
  }
}

async function fetchLessonDetail(token, lessonId) {
  // Note: Kajabi's Public API may not expose lesson detail endpoints.
  // This attempts to fetch lesson details, but gracefully handles 404s.
  // Try with common includes that might expose content
  const params = new URLSearchParams();
  params.set("include", "media,downloads");
  const url = `${API}/v1/lessons/${lessonId}?${params.toString()}`;
  try {
    const json = await jfetch(url, {
      headers: { Authorization: `Bearer ${token}` },
    });
    return json;
  } catch (err) {
    // If detailed fetch fails with 404, the endpoint doesn't exist
    if (err.message.includes("404")) {
      return null; // Signal that lesson detail endpoint is not available
    }
    // If detailed fetch fails, try without includes
    try {
      const basicUrl = `${API}/v1/lessons/${lessonId}`;
      const basicJson = await jfetch(basicUrl, {
        headers: { Authorization: `Bearer ${token}` },
      });
      return basicJson;
    } catch (basicErr) {
      // If both fail with 404, endpoint doesn't exist
      if (basicErr.message.includes("404")) {
        return null;
      }
      throw new Error(`Failed to fetch lesson ${lessonId}: ${err.message}`);
    }
  }
}

(async () => {
  console.log(`Fetching course structure from ${COURSES_FILE}`);
  const token = await getToken();
  const rl = readline.createInterface({
    input: fs.createReadStream(COURSES_FILE),
    crlfDelay: Infinity,
  });

  let idx = 0;
  for await (const line of rl) {
    if (!line.trim()) continue;
    idx += 1;
    if (idx < START) continue;
    if (idx > END) break;

    let record;
    try {
      record = JSON.parse(line);
    } catch (err) {
      appendLine(errorsFile, { course_index: idx, error: `parse error: ${err.message}` });
      continue;
    }
    const courseId = record.id || record.data?.id;
    if (!courseId) {
      appendLine(errorsFile, { course_index: idx, error: "missing course id", raw: record });
      continue;
    }

    console.log(`Course #${idx}: ${courseId}`);
    try {
      const moduleRecords = await fetchCourseInclude(token, courseId, "modules");
      moduleRecords.forEach((mod) =>
        appendLine(modulesFile, { course_id: courseId, module: mod })
      );
      await sleep(DELAY);

      const lessonRecords = await fetchCourseInclude(token, courseId, "lessons");
      lessonRecords.forEach((lesson) =>
        appendLine(lessonsFile, { course_id: courseId, lesson })
      );
      await sleep(DELAY);

      // Fetch detailed lesson content for each lesson
      // Note: Kajabi's Public API may not expose lesson detail endpoints.
      // If the endpoint returns 404, we'll skip detail fetching and continue.
      console.log(`  Fetching details for ${lessonRecords.length} lessons...`);
      let detailFetchAttempted = false;
      let detailFetchSucceeded = false;
      
      for (const lesson of lessonRecords) {
        const lessonId = lesson.id;
        if (!lessonId) continue;
        
        try {
          const detail = await fetchLessonDetail(token, lessonId);
          detailFetchAttempted = true;
          
          if (detail === null) {
            // Endpoint doesn't exist (404) - skip silently after first attempt
            if (!detailFetchSucceeded) {
              console.log(`    Lesson detail endpoint not available (404) - skipping detail fetches`);
            }
            break; // Stop trying for remaining lessons
          }
          
          detailFetchSucceeded = true;
          appendLine(lessonDetailsFile, {
            course_id: courseId,
            lesson_id: lessonId,
            detail: detail.data || detail,
            included: detail.included || [],
          });
          await sleep(DELAY);
        } catch (err) {
          detailFetchAttempted = true;
          appendLine(errorsFile, {
            course_id: courseId,
            lesson_id: lessonId,
            error: `lesson_detail_fetch_failed: ${err.message}`,
          });
          // Continue with other lessons even if one fails
        }
      }
      
      if (detailFetchAttempted && !detailFetchSucceeded) {
        console.log(`  Note: Lesson detail endpoint not available in Kajabi API - using metadata only`);
      }

      const mediaRecords = await fetchCourseLessonMedia(token, courseId);
      if (Array.isArray(mediaRecords)) {
        mediaRecords
          .filter((item) => item.type === "media")
          .forEach((media) =>
            appendLine(mediaFile, { course_id: courseId, media })
          );
      } else if (mediaRecords?.error) {
        appendLine(errorsFile, {
          course_id: courseId,
          error: `media_fetch_failed: ${mediaRecords.error}`,
        });
      }
    } catch (err) {
      appendLine(errorsFile, { course_id: courseId, error: err.message });
    }
  }
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
