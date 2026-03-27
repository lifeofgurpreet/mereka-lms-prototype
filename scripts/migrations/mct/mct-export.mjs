#!/usr/bin/env node

/**
 * Microsoft Community Training (MCT) API exporter
 *
 * Exports data from MCT platform to NDJSON files for transformation and import into Open edX.
 *
 * Based on working authentication pattern from hubspot-webhook-mct project.
 *
 * Usage:
 *   # Export all resources using service-to-service auth (recommended):
 *   MCT_BASE_URL=https://learn.skillourfuture.org \
 *   MCT_API_URI=api://bf8331fd-17ed-4bcf-af5f-599db14ff4f4 \
 *   MCT_CLIENT_ID=<client-id> \
 *   MCT_CLIENT_SECRET=<client-secret> \
 *   MCT_TENANT_ID=<tenant-id> \
 *   node scripts/migrations/mct/mct-export.mjs
 *
 *   # Export using pre-obtained Bearer token:
 *   MCT_BASE_URL=https://learn.skillourfuture.org \
 *   MCT_ACCESS_TOKEN=<token> \
 *   node scripts/migrations/mct/mct-export.mjs
 *
 *   # Export specific resources:
 *   node scripts/migrations/mct/mct-export.mjs --resources users,courses,enrollments
 *
 *   # Chunked export (pages 1-50):
 *   node scripts/migrations/mct/mct-export.mjs --resources users --start-page 1 --end-page 50
 *
 *   # Dry run (test without exporting):
 *   node scripts/migrations/mct/mct-export.mjs --dry-run
 *
 *   # Force overwrite existing files:
 *   node scripts/migrations/mct/mct-export.mjs --force
 *
 * Environment variables:
 *   MCT_BASE_URL          - Base URL of MCT instance (required, e.g., learn.skillourfuture.org)
 *   MCT_API_VERSION       - API version: v1, v2, v3, or v4 (default: v1, recommended for migration)
 *   MCT_ACCESS_TOKEN      - Bearer token for authentication (if not using service-to-service auth)
 *   MCT_CLIENT_ID         - Service principal ID (for service-to-service auth)
 *   MCT_CLIENT_SECRET     - Service principal secret (for service-to-service auth)
 *   MCT_TENANT_ID         - Azure tenant ID (for service-to-service auth)
 *   MCT_API_URI           - API URI scope (for service-to-service auth, e.g., api://bf8331fd-17ed-4bcf-af5f-599db14ff4f4)
 */

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const DEFAULT_RESOURCES = [
  "organizations",   // V1: /api/v1/organization ✅
  "users",          // V1/V2/V3: /api/v*/Reports/Users (CSV bulk export) ✅
  "categories",     // V3: /api/v3/admin/categoriesAndCourses (hierarchical) ✅
  "courses",        // V1: /api/v1/Courses (hierarchical), V3: /api/v3/Courses ✅
  "groups",         // V1: /api/v1/Groups (learning pathways with rules) ✅
  "learningpaths",  // V1: /api/v1/learningpaths ✅
  "certificates",   // V1: /api/v1/Certificates ✅
  "enrollments",    // V1: /api/v1/Reports/Course/{courseId}/Learners (REAL enrollment data per course) ✅
];

// -------- Configuration ------------------------------------------------------

const argv = process.argv.slice(2);
const options = parseArgs(argv);

const MCT_BASE_URL = options["base-url"] || process.env.MCT_BASE_URL;
const MCT_API_VERSION = options["api-version"] || process.env.MCT_API_VERSION || "v1";
const MCT_ACCESS_TOKEN = options["token"] || process.env.MCT_ACCESS_TOKEN;
const MCT_CLIENT_ID = options["client-id"] || process.env.MCT_CLIENT_ID;
const MCT_CLIENT_SECRET = options["client-secret"] || process.env.MCT_CLIENT_SECRET;
const MCT_TENANT_ID = options["tenant-id"] || process.env.MCT_TENANT_ID;
const MCT_API_URI = options["api-uri"] || process.env.MCT_API_URI;

if (!MCT_BASE_URL) {
  console.error("Missing MCT_BASE_URL (e.g., learn.skillourfuture.org)");
  process.exit(1);
}

// Normalize base URL (remove https:// if present, working code uses domain only)
const normalizedBaseUrl = MCT_BASE_URL.replace(/^https?:\/\//, "").replace(/\/$/, "");

const DRY_RUN = options["dry-run"] || options["dryrun"] || false;

// Skip authentication validation in dry-run mode
if (!DRY_RUN) {
  if (!MCT_ACCESS_TOKEN && (!MCT_CLIENT_ID || !MCT_CLIENT_SECRET || !MCT_TENANT_ID)) {
    console.error("Missing authentication:");
    console.error("  Option 1: Provide MCT_ACCESS_TOKEN (Bearer token)");
    console.error("  Option 2: Provide MCT_CLIENT_ID, MCT_CLIENT_SECRET, MCT_TENANT_ID, and MCT_API_URI");
    process.exit(1);
  }

  if (!MCT_ACCESS_TOKEN && !MCT_API_URI) {
    console.error("Missing MCT_API_URI (required for service-to-service auth, e.g., api://bf8331fd-17ed-4bcf-af5f-599db14ff4f4)");
    process.exit(1);
  }
}

const OUT_DIR = path.resolve(options.out || "./exports/mct");
const PAGE_SIZE = Number(options["page-size"] || 100);
const START_PAGE = Number(options["start-page"] || 1);
const END_PAGE = options["end-page"] !== undefined ? Number(options["end-page"]) : undefined;
const FORCE = options.force || false;
const RESOURCES = (options.resources
  ? options.resources.split(",")
  : DEFAULT_RESOURCES
).map((r) => r.trim()).filter(Boolean);

// Validation
if (START_PAGE < 1) {
  console.error("START_PAGE must be >= 1");
  process.exit(1);
}
if (PAGE_SIZE < 1 || PAGE_SIZE > 1000) {
  console.error("PAGE_SIZE must be between 1 and 1000");
  process.exit(1);
}
if (END_PAGE !== undefined && END_PAGE < START_PAGE) {
  console.error("END_PAGE must be >= START_PAGE");
  process.exit(1);
}

fs.mkdirSync(OUT_DIR, { recursive: true });

const API_BASE = `https://${normalizedBaseUrl}/api/${MCT_API_VERSION}`;
const API_BASE_V1 = `https://${normalizedBaseUrl}/api/v1`;
const API_BASE_V3 = `https://${normalizedBaseUrl}/api/v3`;

// Resource to endpoint mapping (version-specific)
// Based on actual endpoints used in hubspot-webhook-mct and Swagger API exploration
const RESOURCE_ENDPOINTS = {
  users: {
    v1: "/Reports/Users", // Bulk user export (CSV format) ✅
    v2: "/Reports/Users", // Also available in V2 ✅
    v3: "/Reports/Users", // Also available in V3 ✅
  },
  organizations: {
    v1: "/organization", // ✅ Verified: /api/v1/organization
    v2: null,
    v3: null,
  },
  categories: {
    v1: "/Category", // Basic category list
    v2: "/Category", // With localized data
    v3: "/admin/categoriesAndCourses", // ✅ Hierarchical structure (categories + courses)
  },
  courses: {
    v1: "/Courses", // Returns hierarchical structure (categories containing courses)
    v2: "/Courses", // With localized data
    v3: "/Courses", // ✅ Get all registered courses for user
    v4: null, // V4 doesn't have list endpoint
  },
  groups: {
    v1: "/Groups", // ✅ Learning pathways/user groups with rules
    v2: null,
    v3: null,
  },
  certificates: {
    v1: "/Certificates", // ✅ Get all certificates for a user
    v2: null,
    v3: null,
  },
  enrollments: {
    // REAL enrollment data via V1 Reports endpoint
    v1: "/Reports/Course/{courseId}/Learners", // ✅ REAL learner data with completion, progress, etc.
    v2: null,
    v3: null, // V3 /course/{courseId}/Reports/Users may not exist or is incorrect
    v4: null,
  },
  learningpaths: {
    v1: "/learningpaths", // ✅ Get learning paths
    v2: "/learningpaths", // Also in V2
    v3: null,
  },
  reports: {
    v1: "/Reports/Users", // ✅ General user report
    v2: "/Reports/Users", // Also in V2
    v3: "/Reports/Users", // Also in V3
  },
};

// -------- Argument parsing ---------------------------------------------------

function parseArgs(argv) {
  const opts = {};
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg.startsWith("--")) {
      const key = arg.slice(2);
      const next = argv[i + 1];
      if (next && !next.startsWith("--")) {
        opts[key] = next;
        i++;
      } else {
        opts[key] = true;
      }
    }
  }
  return opts;
}

// -------- HTTP helpers -------------------------------------------------------

const MAX_ATTEMPTS = 3;

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/**
 * Fetch with retry logic and MCT-specific headers.
 * Based on working pattern from hubspot-webhook-mct/functions/index.js
 * Handles both JSON and CSV responses (Reports endpoints return CSV)
 */
async function jfetch(url, opts = {}, attempt = 1) {
  // Ensure MCT-specific headers are present
  const headers = {
    "Accept": "application/json",
    "ClientType": "service", // Required by MCT API
    ...opts.headers,
  };

  const res = await fetch(url, { ...opts, headers });
  
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
  
  // Check if response is CSV (Reports endpoints)
  const contentType = res.headers.get("content-type") || "";
  if (contentType.includes("text/csv") || contentType.includes("application/vnd.ms-excel")) {
    const csvText = await res.text();
    return parseCSV(csvText);
  }
  
  // Check if response is ZIP file (some Reports endpoints return ZIP)
  const contentDisposition = res.headers.get("content-disposition") || "";
  if (contentType.includes("application/zip") || contentType.includes("application/x-zip-compressed") || 
      contentDisposition.includes(".zip") || contentType.includes("application/octet-stream")) {
    // ZIP file - return as binary data indicator (skip for now, could extract if needed)
    console.warn(`[WARNING] Endpoint returned ZIP file - skipping automatic extraction. Save manually if needed.`);
    return { _zip_file: true, _content_type: contentType, _content_disposition: contentDisposition };
  }
  
  return res.json();
}

/**
 * Parse CSV text into array of objects
 */
function parseCSV(csvText) {
  const lines = csvText.trim().split("\n");
  if (lines.length === 0) return [];
  
  // Parse header
  const headers = lines[0].split(",").map(h => h.trim().replace(/^"|"$/g, ""));
  
  // Parse data rows
  const data = [];
  for (let i = 1; i < lines.length; i++) {
    if (!lines[i].trim()) continue;
    const values = lines[i].split(",").map(v => v.trim().replace(/^"|"$/g, ""));
    const obj = {};
    headers.forEach((header, idx) => {
      obj[header] = values[idx] || "";
    });
    data.push(obj);
  }
  
  return data;
}

// -------- Authentication -----------------------------------------------------

let cachedToken = null;

/**
 * Get MCT API Bearer token using service-to-service authentication.
 * Based on working pattern from hubspot-webhook-mct/functions/index.js
 */
async function getToken() {
  if (cachedToken) return cachedToken;

  // Use pre-provided token if available
  if (MCT_ACCESS_TOKEN) {
    cachedToken = MCT_ACCESS_TOKEN;
    return cachedToken;
  }

  // Service-to-Service authentication (Azure AD OAuth2 client credentials flow)
  if (MCT_CLIENT_ID && MCT_CLIENT_SECRET && MCT_TENANT_ID && MCT_API_URI) {
    // Use login.microsoft.com (matches working code pattern)
    const tokenEndpoint = `https://login.microsoft.com/${MCT_TENANT_ID}/oauth2/v2.0/token`;
    
    // Build form-encoded body (matching working code pattern)
    const data = `grant_type=client_credentials&client_id=${encodeURIComponent(
      MCT_CLIENT_ID
    )}&scope=${encodeURIComponent(
      `${MCT_API_URI}/.default`
    )}&client_secret=${encodeURIComponent(MCT_CLIENT_SECRET)}`;

    try {
      const response = await fetch(tokenEndpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "Content-Length": Buffer.byteLength(data).toString(),
        },
        body: data,
      });

      if (!response.ok) {
        const text = await response.text().catch(() => "");
        throw new Error(`Token request failed [${response.status}]: ${text}`);
      }

      const tokenData = await response.json();

      if (tokenData.access_token) {
        cachedToken = tokenData.access_token;
        console.log("✓ Successfully obtained MCT API token");
        return cachedToken;
      } else {
        throw new Error("Token response missing access_token");
      }
    } catch (error) {
      console.error("Error obtaining MCT API token:", error.message);
      throw error;
    }
  }

  throw new Error("No authentication method available");
}

// -------- Export helpers -----------------------------------------------------

function appendLine(path, obj) {
  fs.appendFileSync(path, JSON.stringify(obj) + "\n");
}

async function exportCollection(token, resource, version = MCT_API_VERSION, params = {}) {
  const endpointMap = RESOURCE_ENDPOINTS[resource];
  if (!endpointMap) {
    console.warn(`[${resource}] Unknown resource, skipping.`);
    return;
  }

  // Determine which version to use
  let apiVersion = version;
  let endpoint = endpointMap[version];
  
  // Fallback to V1 if V3 doesn't have the endpoint
  if (!endpoint && version === "v3" && endpointMap.v1) {
    console.log(`[${resource}] V3 endpoint not available, falling back to V1`);
    apiVersion = "v1";
    endpoint = endpointMap.v1;
  }
  
  // Fallback to V3 if V1 doesn't have the endpoint
  if (!endpoint && version === "v1" && endpointMap.v3) {
    console.log(`[${resource}] V1 endpoint not available, falling back to V3`);
    apiVersion = "v3";
    endpoint = endpointMap.v3;
  }

  if (!endpoint) {
    console.warn(`[${resource}] Endpoint not available in ${version}, skipping.`);
    return;
  }

  const apiBase = apiVersion === "v1" ? API_BASE_V1 : apiVersion === "v3" ? API_BASE_V3 : API_BASE;
  const outPath = path.join(OUT_DIR, `${resource}.ndjson`);
  
  if (fs.existsSync(outPath) && !FORCE) {
    console.log(`[${resource}] File exists, skipping. Use --force to overwrite or delete ${outPath} to re-export.`);
    return;
  }
  
  if (DRY_RUN) {
    console.log(`[${resource}] DRY RUN: Would export from ${apiVersion} endpoint: ${endpoint}`);
    console.log(`[${resource}] DRY RUN: Would write to: ${outPath}`);
    return;
  }
  
  // Clear file if forcing overwrite
  if (FORCE && fs.existsSync(outPath)) {
    fs.unlinkSync(outPath);
    console.log(`[${resource}] Overwriting existing file: ${outPath}`);
  }

  console.log(`[${resource}] Starting export from ${apiVersion}...`);
  let page = START_PAGE;
  let totalRecords = 0;
  let hasMore = true;

  while (hasMore && (END_PAGE === undefined || page <= END_PAGE)) {
    const queryParams = new URLSearchParams({
      page: String(page),
      pageSize: String(PAGE_SIZE),
      ...params,
    });

    const url = `${apiBase}${endpoint}?${queryParams}`;
    console.log(`[${resource}] Fetching page ${page} from ${url}...`);

    try {
      const data = await jfetch(url, {
        headers: {
          Authorization: `Bearer ${token}`,
          ClientType: "service",
        },
      });

      // Handle different response structures
      let items = [];
      if (Array.isArray(data)) {
        items = data;
      } else if (data.items) {
        items = data.items;
      } else if (data.data) {
        items = Array.isArray(data.data) ? data.data : [data.data];
      } else if (data.results) {
        items = data.results;
      } else if (resource === "categories" && apiVersion === "v3") {
        // V3 categoriesAndCourses returns hierarchical structure
        items = [data]; // Store entire structure as one record
        hasMore = false; // No pagination for this endpoint
      } else {
        // Try to find array-like structure
        const keys = Object.keys(data);
        for (const key of keys) {
          if (Array.isArray(data[key])) {
            items = data[key];
            break;
          }
        }
      }

      const pagination = data.pagination || data.meta || {};

      if (!Array.isArray(items) || items.length === 0) {
        hasMore = false;
        break;
      }

      for (const item of items) {
        appendLine(outPath, item);
        totalRecords++;
      }

      // Check if there are more pages
      hasMore = pagination.hasNextPage !== false && items.length === PAGE_SIZE && resource !== "categories";
      page++;

      // Rate limiting
      await sleep(200);
    } catch (error) {
      console.error(`[${resource}] Error on page ${page}:`, error.message);
      if (error.message.includes("404")) {
        console.warn(`[${resource}] Endpoint not found, skipping.`);
        hasMore = false;
      } else {
        throw error;
      }
    }
  }

  console.log(`[${resource}] Exported ${totalRecords} records to ${outPath}`);
}

async function exportCourses(token, params = {}) {
  const coursesPath = path.join(OUT_DIR, "courses.ndjson");
  const categoriesPath = path.join(OUT_DIR, "categories.ndjson");

  // Clear courses file if forcing overwrite
  if (FORCE && fs.existsSync(coursesPath)) {
    fs.unlinkSync(coursesPath);
    console.log(`[courses] Overwriting existing file: ${coursesPath}`);
  }

  // Check if we should use categories.ndjson to get all courses
  // V3 categoriesAndCourses returns: { Offers: [...categories], CourseItems: [...courses] }
  let allCategories = [];
  let allCourseItems = [];

  if (fs.existsSync(categoriesPath)) {
    console.log("[courses] Extracting courses from categories.ndjson (V3 hierarchical structure)...");
    const categoriesData = fs.readFileSync(categoriesPath, "utf-8")
      .split("\n")
      .filter(Boolean)
      .map((line) => JSON.parse(line));

    // V3 categoriesAndCourses returns hierarchical structure with "Offers" and "CourseItems" arrays
    for (const data of categoriesData) {
      if (data.Offers && Array.isArray(data.Offers)) {
        allCategories = data.Offers;
        console.log(`[courses] Found ${allCategories.length} categories`);
      }
      if (data.CourseItems && Array.isArray(data.CourseItems)) {
        allCourseItems = data.CourseItems;
        console.log(`[courses] Found ${allCourseItems.length} course items (MCT courses = Open edX modules)`);
      }
    }
  }

  // If we didn't get data from file, try fetching from API
  if (allCategories.length === 0 || allCourseItems.length === 0) {
    console.log("[courses] No categories.ndjson found or incomplete, fetching from V3 API...");
    try {
      const categoriesUrl = `${API_BASE_V3}/admin/categoriesAndCourses`;
      const categoriesData = await jfetch(categoriesUrl, {
        headers: {
          Authorization: `Bearer ${token}`,
          ClientType: "service",
        },
      });

      if (categoriesData.Offers && Array.isArray(categoriesData.Offers)) {
        allCategories = categoriesData.Offers;
        console.log(`[courses] Fetched ${allCategories.length} categories from API`);
      }
      if (categoriesData.CourseItems && Array.isArray(categoriesData.CourseItems)) {
        allCourseItems = categoriesData.CourseItems;
        console.log(`[courses] Fetched ${allCourseItems.length} course items from API`);
      }
    } catch (error) {
      console.error("[courses] Failed to fetch categories:", error.message);
      console.warn("[courses] Falling back to V1 Courses endpoint...");
      await exportCollection(token, "courses", MCT_API_VERSION, params);
      return;
    }
  }

  // Build category ID to name lookup
  const categoryLookup = new Map();
  for (const category of allCategories) {
    const categoryName = category.Names?.find(n => n.LanguageCode === category.DefaultLanguageCode)?.Value
                      || category.Names?.[0]?.Value
                      || "Unknown Category";
    categoryLookup.set(category.Id, categoryName.trim());
  }

  // Write all course items to courses.ndjson
  // CourseItems structure: { Id, ParentId (=CategoryId), Name, Description, Logo, NumPublishedLessons, ... }
  let totalCourses = 0;
  const coursesPerCategory = new Map();

  for (const course of allCourseItems) {
    const categoryId = course.ParentId;
    const categoryName = categoryLookup.get(categoryId) || "Unknown Category";

    appendLine(coursesPath, {
      ...course,
      CategoryId: categoryId,
      CategoryName: categoryName,
    });
    totalCourses++;

    // Track count per category
    coursesPerCategory.set(categoryId, (coursesPerCategory.get(categoryId) || 0) + 1);
  }

  // Report per-category counts
  for (const category of allCategories) {
    const categoryId = category.Id;
    const categoryName = categoryLookup.get(categoryId);
    const count = coursesPerCategory.get(categoryId) || 0;
    if (count > 0) {
      console.log(`[courses] ✓ Category "${categoryName}" (ID: ${categoryId}): ${count} courses`);
    } else {
      console.log(`[courses] ⚠ Category "${categoryName}" (ID: ${categoryId}): No courses`);
    }
  }

  console.log(`[courses] Extracted ${totalCourses} courses from ${allCategories.length} categories`);

  // Then fetch detailed course content for each course using V3
  if (!fs.existsSync(coursesPath)) {
    console.warn("[courses] No courses.ndjson found, skipping course content export");
    return;
  }

  const structureDir = path.join(OUT_DIR, "structure");
  fs.mkdirSync(structureDir, { recursive: true });

  console.log("[courses] Fetching course content details from V3...");
  const courses = fs.readFileSync(coursesPath, "utf-8")
    .split("\n")
    .filter(Boolean)
    .map((line) => JSON.parse(line));

  for (const course of courses) {
    const courseId = course.Id || course.ProductId || course.courseId || course.id || course.course_id || course.CourseId;
    if (!courseId) {
      console.warn("[courses] Skipping course without ID:", course);
      continue;
    }

    try {
      // Fetch course content/structure from V3
      const contentUrl = `${API_BASE_V3}/Courses/${courseId}/Content`;
      const content = await jfetch(contentUrl, {
        headers: {
          Authorization: `Bearer ${token}`,
          ClientType: "service",
        },
      });

      appendLine(path.join(structureDir, "course_content.ndjson"), {
        courseId,
        categoryId: course.CategoryId,
        categoryName: course.CategoryName,
        ...content,
      });

      // Also fetch metadata
      try {
        const metadataUrl = `${API_BASE_V3}/Courses/${courseId}/Metadata`;
        const metadata = await jfetch(metadataUrl, {
          headers: {
            Authorization: `Bearer ${token}`,
            ClientType: "service",
          },
        });
        appendLine(path.join(structureDir, "course_metadata.ndjson"), {
          courseId,
          categoryId: course.CategoryId,
          categoryName: course.CategoryName,
          ...metadata,
        });
      } catch (err) {
        console.warn(`[courses] Metadata not available for course ${courseId}`);
      }

      // Also fetch certificate info if available
      try {
        const certificateUrl = `${API_BASE_V3}/Courses/${courseId}/Certificate`;
        const certificate = await jfetch(certificateUrl, {
          headers: {
            Authorization: `Bearer ${token}`,
            ClientType: "service",
          },
        });
        appendLine(path.join(structureDir, "course_certificates.ndjson"), {
          courseId,
          categoryId: course.CategoryId,
          categoryName: course.CategoryName,
          ...certificate,
        });
      } catch (err) {
        // Certificate endpoint may not exist for all courses, skip silently
      }

      await sleep(200);
    } catch (error) {
      if (error.message.includes("404")) {
        console.warn(`[courses] Content endpoint not available for course ${courseId}`);
      } else {
        console.error(`[courses] Error fetching content for ${courseId}:`, error.message);
      }
    }
  }
}

/**
 * Export enrollments per course using V1 Reports/Course/{courseId}/Learners endpoint.
 * This endpoint returns REAL enrollment data including completion status, progress, etc.
 *
 * According to V1_COMPLETE.md:
 * - GET /api/v1/Reports/Course/{courseId}/Learners - Download learners in course analytics
 * - GET /api/v1/Course/{courseId}/users - Search users in the course (alternative)
 */
async function exportEnrollments(token) {
  const outPath = path.join(OUT_DIR, "enrollments.ndjson");

  if (fs.existsSync(outPath) && !FORCE) {
    console.log(`[enrollments] File exists, skipping. Use --force to overwrite or delete ${outPath} to re-export.`);
    return;
  }

  if (DRY_RUN) {
    console.log(`[enrollments] DRY RUN: Would export enrollments per course from V1 Reports/Course/{courseId}/Learners`);
    console.log(`[enrollments] DRY RUN: Would write to: ${outPath}`);
    return;
  }

  // Clear file if forcing overwrite
  if (FORCE && fs.existsSync(outPath)) {
    fs.unlinkSync(outPath);
    console.log(`[enrollments] Overwriting existing file: ${outPath}`);
  }

  // Need courses list first to get enrollments per course
  const coursesPath = path.join(OUT_DIR, "courses.ndjson");
  if (!fs.existsSync(coursesPath)) {
    console.warn("[enrollments] No courses.ndjson found. Export courses first.");
    return;
  }

  console.log("[enrollments] Fetching REAL enrollment data per course from V1 Reports/Course/{courseId}/Learners...");
  const courses = fs.readFileSync(coursesPath, "utf-8")
    .split("\n")
    .filter(Boolean)
    .map((line) => JSON.parse(line));

  // Extract all course IDs (note: Id is the field name from V3 categoriesAndCourses CourseItems)
  const courseIds = new Set();
  for (const item of courses) {
    const courseId = item.Id || item.ProductId || item.courseId || item.id || item.course_id || item.CourseId;
    if (courseId) courseIds.add(courseId);
  }

  console.log(`[enrollments] Found ${courseIds.size} courses to fetch enrollments for...`);

  let totalEnrollments = 0;
  let successfulCourses = 0;
  let failedCourses = 0;

  for (const courseId of courseIds) {
    try {
      // Use V1 Reports endpoint to get REAL learner data
      const enrollmentUrl = `${API_BASE_V1}/Reports/Course/${courseId}/Learners`;
      console.log(`[enrollments] Fetching learners for course ${courseId}...`);

      const enrollmentData = await jfetch(enrollmentUrl, {
        headers: {
          Authorization: `Bearer ${token}`,
          ClientType: "service",
        },
      });

      // Handle different response formats (CSV, JSON, or ZIP)
      let enrollments = [];
      if (Array.isArray(enrollmentData)) {
        // Direct array of learners
        enrollments = enrollmentData;
      } else if (typeof enrollmentData === 'object' && enrollmentData._zip_file) {
        // ZIP file response - warn and skip
        console.warn(`[enrollments] Course ${courseId} returned ZIP file, skipping (download manually if needed)`);
        failedCourses++;
        continue;
      } else if (typeof enrollmentData === 'object') {
        // Try to extract array from response object
        const keys = Object.keys(enrollmentData);
        for (const key of keys) {
          if (Array.isArray(enrollmentData[key])) {
            enrollments = enrollmentData[key];
            break;
          }
        }
      }

      if (enrollments.length === 0) {
        console.log(`[enrollments] No enrollments found for course ${courseId}`);
      } else {
        // Write enrollments with courseId reference
        for (const enrollment of enrollments) {
          appendLine(outPath, {
            courseId,
            ...enrollment,
          });
          totalEnrollments++;
        }
        console.log(`[enrollments] ✓ Course ${courseId}: ${enrollments.length} learners`);
        successfulCourses++;
      }

      await sleep(200); // Rate limiting
    } catch (error) {
      if (error.message.includes("404")) {
        console.warn(`[enrollments] ✗ Course ${courseId}: Endpoint not found (course may have no enrollments)`);
      } else {
        console.error(`[enrollments] ✗ Course ${courseId}: ${error.message}`);
      }
      failedCourses++;
    }
  }

  console.log(`[enrollments] Export complete:`);
  console.log(`[enrollments]   Total enrollments: ${totalEnrollments}`);
  console.log(`[enrollments]   Successful courses: ${successfulCourses}/${courseIds.size}`);
  console.log(`[enrollments]   Failed courses: ${failedCourses}/${courseIds.size}`);
  console.log(`[enrollments]   Output: ${outPath}`);
}

// -------- Main execution -----------------------------------------------------

(async () => {
  console.log("=".repeat(60));
  console.log("MCT Data Export Tool");
  console.log("=".repeat(60));
  console.log(`Base URL: ${normalizedBaseUrl}`);
  console.log(`API Version: ${MCT_API_VERSION}`);
  console.log(`Output Directory: ${OUT_DIR}`);
  console.log(`Resources: ${RESOURCES.join(", ")}`);
  console.log(`Page Size: ${PAGE_SIZE}`);
  if (END_PAGE !== undefined) {
    console.log(`Page Range: ${START_PAGE} - ${END_PAGE}`);
  }
  if (DRY_RUN) {
    console.log("⚠️  DRY RUN MODE - No files will be written");
  }
  if (FORCE) {
    console.log("⚠️  FORCE MODE - Existing files will be overwritten");
  }
  console.log("=".repeat(60));
  
  if (DRY_RUN) {
    console.log("\n[DRY RUN] Skipping authentication...");
    console.log("[DRY RUN] Would authenticate with MCT API...");
    
    // Dry run: just show what would be exported
    for (const resource of RESOURCES) {
      const endpointMap = RESOURCE_ENDPOINTS[resource];
      if (!endpointMap) {
        console.warn(`[${resource}] Unknown resource, skipping.`);
        continue;
      }
      
      // Determine which version would be used
      let apiVersion = MCT_API_VERSION;
      let endpoint = endpointMap[apiVersion];
      
      if (!endpoint && apiVersion === "v3" && endpointMap.v1) {
        apiVersion = "v1";
        endpoint = endpointMap.v1;
      } else if (!endpoint && apiVersion === "v1" && endpointMap.v3) {
        apiVersion = "v3";
        endpoint = endpointMap.v3;
      }
      
      if (endpoint) {
        const apiBase = apiVersion === "v1" ? API_BASE_V1 : apiVersion === "v3" ? API_BASE_V3 : API_BASE;
        const url = `${apiBase}${endpoint}`;
        console.log(`[${resource}] Would export from ${apiVersion}: ${url}`);
      } else if (resource === "enrollments") {
        console.log(`[${resource}] Would export enrollments per course from V3: ${API_BASE_V3}/course/{courseId}/Reports/Users`);
      } else {
        console.warn(`[${resource}] No endpoint available for ${MCT_API_VERSION}`);
      }
    }
  } else {
    console.log("\nAuthenticating with MCT...");
    const token = await getToken();
    console.log(`✓ Using API: ${API_BASE}`);
    
    // Export resources in logical order
    for (const resource of RESOURCES) {
      try {
        switch (resource) {
        case "organizations":
          // Export organizations first (needed for org mapping)
          await exportCollection(token, resource, "v1");
          break;
        case "courses":
          await exportCourses(token);
          break;
        case "categories":
          // Use V3 for hierarchical structure (categories + courses)
          await exportCollection(token, resource, "v3");
          break;
        case "users":
        case "groups":
        case "certificates":
        case "learningpaths":
          // Use V1
          await exportCollection(token, resource, "v1");
          break;
        case "enrollments":
          // Special handling: fetch per course from V3
          await exportEnrollments(token);
          break;
        case "reports":
          // Try V3 first, fallback to V1
          await exportCollection(token, resource, "v3");
          break;
        default:
          console.warn(`Unknown resource "${resource}" – skipping.`);
      }
      } catch (error) {
        console.error(`Failed to export ${resource}:`, error.message);
        // Continue with other resources instead of exiting
        process.exitCode = 1;
      }
    }
    
    // Generate summary report
    console.log("\n" + "=".repeat(60));
    console.log("Export Summary");
    console.log("=".repeat(60));
    
    const exportedFiles = [];
    for (const resource of RESOURCES) {
      const filePath = path.join(OUT_DIR, `${resource}.ndjson`);
      if (fs.existsSync(filePath)) {
        const stats = fs.statSync(filePath);
        const lineCount = fs.readFileSync(filePath, "utf-8")
          .split("\n")
          .filter(Boolean).length;
        exportedFiles.push({
          resource,
          path: filePath,
          size: stats.size,
          records: lineCount,
        });
        console.log(`✓ ${resource.padEnd(15)} ${lineCount.toString().padStart(6)} records  ${(stats.size / 1024).toFixed(1)} KB`);
      }
    }
    
    if (exportedFiles.length === 0) {
      console.log("No files were exported.");
    } else {
      const totalRecords = exportedFiles.reduce((sum, f) => sum + f.records, 0);
      const totalSize = exportedFiles.reduce((sum, f) => sum + f.size, 0);
      console.log("-".repeat(60));
      console.log(`Total: ${exportedFiles.length} files, ${totalRecords} records, ${(totalSize / 1024).toFixed(1)} KB`);
    }
    
    console.log(`\nOutput directory: ${OUT_DIR}`);
    console.log("=".repeat(60));
  }
})();

