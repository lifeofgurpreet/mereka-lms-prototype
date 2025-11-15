#!/usr/bin/env node
/**
 * Export certificate eligibility data from Kajabi
 * 
 * IMPORTANT: Kajabi's Public API does NOT expose certificate issuance data.
 * See docs/KAJABI_API_ENDPOINTS.md for the complete list of available endpoints.
 * 
 * This script:
 * 1. Tests certificate/completion endpoints (all return 404 - not available)
 * 2. Exports purchase data as a proxy for certificate eligibility
 *    (users who purchased/enrolled are eligible for certificates)
 * 
 * To get actual certificate data:
 * - Manual export from Kajabi Dashboard: Analytics → Certificates
 * - Or use third-party integrations (Accredible, SimpleCert via Zapier)
 * 
 * Usage:
 *   node scripts/migrations/kajabi/kajabi-export-certificates.mjs
 */

import fs from "node:fs";
import path from "node:path";

const API = "https://api.kajabi.com";
const CLIENT_ID = process.env.KAJABI_CLIENT_ID;
const CLIENT_SECRET = process.env.KAJABI_CLIENT_SECRET;
const OUT_DIR = path.resolve("./exports/kajabi");

if (!CLIENT_ID || !CLIENT_SECRET) {
  console.error("Missing KAJABI_CLIENT_ID or KAJABI_CLIENT_SECRET");
  process.exit(1);
}

const MAX_ATTEMPTS = 3;
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

function readNdjson(filepath) {
  if (!fs.existsSync(filepath)) return [];
  return fs
    .readFileSync(filepath, "utf-8")
    .split("\n")
    .filter(Boolean)
    .map((line) => JSON.parse(line));
}

async function attemptCertificateExport(token) {
  console.log("Attempting to find certificate/completion endpoints...");
  
  // Try various possible endpoints
  const endpoints = [
    "/v1/certificates",
    "/v1/completions",
    "/v1/course_completions",
    "/v1/achievements",
  ];
  
  const results = {};
  
  for (const endpoint of endpoints) {
    try {
      const url = `${API}${endpoint}`;
      const data = await jfetch(url, {
        headers: { Authorization: `Bearer ${token}` },
      });
      results[endpoint] = { success: true, data };
      console.log(`✓ Found endpoint: ${endpoint}`);
    } catch (err) {
      if (err.message.includes("404")) {
        results[endpoint] = { success: false, error: "Not found" };
      } else {
        results[endpoint] = { success: false, error: err.message };
      }
    }
  }
  
  return results;
}

async function exportCompletionData(token) {
  // Since certificates aren't available via API, we'll create a completion eligibility
  // list based on purchases (enrollments) - users who purchased/completed courses
  // are eligible for certificates
  
  console.log("Building certificate eligibility from purchase data...");
  
  const purchases = readNdjson(path.join(OUT_DIR, "purchases.ndjson"));
  const courses = readNdjson(path.join(OUT_DIR, "courses_index.ndjson"));
  const customers = readNdjson(path.join(OUT_DIR, "customers.ndjson"));
  const contacts = readNdjson(path.join(OUT_DIR, "contacts.ndjson"));
  
  const courseMap = {};
  for (const course of courses) {
    courseMap[course.id] = course;
  }
  
  const customerMap = {};
  for (const customer of customers) {
    customerMap[customer.id] = customer;
  }
  
  const contactMap = {};
  for (const contact of contacts) {
    contactMap[contact.id] = contact;
  }
  
  // Build customer -> contact mapping
  const customerToContact = {};
  for (const customer of customers) {
    const contactRel = customer.relationships?.contact?.data;
    if (contactRel) {
      customerToContact[customer.id] = contactRel.id;
    }
  }
  
  const certificateEligibility = [];
  
  for (const purchase of purchases) {
    const customerId = purchase.relationships?.customer?.data?.id;
    const contactId = customerToContact[customerId] || "";
    const products = purchase.relationships?.products?.data || [];
    
    const customer = customerMap[customerId];
    const contact = contactMap[contactId];
    const email = contact?.attributes?.email || customer?.attributes?.email || "";
    const name = contact?.attributes?.name || customer?.attributes?.name || "";
    
    for (const product of products) {
      const courseId = product.id;
      const course = courseMap[courseId];
      
      if (course) {
        certificateEligibility.push({
          purchase_id: purchase.id,
          customer_id: customerId,
          contact_id: contactId,
          email: email,
          name: name,
          course_id: courseId,
          course_title: course.attributes?.title || "",
          enrolled_at: purchase.attributes?.created_at || "",
          is_active: !purchase.attributes?.deactivated_at,
          // Note: Actual certificate issuance status not available via API
          // This represents eligibility based on enrollment
          certificate_eligible: true,
          certificate_status: "unknown", // Would need manual verification
        });
      }
    }
  }
  
  const outputFile = path.join(OUT_DIR, "certificate_eligibility.ndjson");
  fs.writeFileSync(outputFile, "");
  for (const record of certificateEligibility) {
    fs.appendFileSync(outputFile, JSON.stringify(record) + "\n");
  }
  
  console.log(`✓ Exported ${certificateEligibility.length} certificate eligibility records`);
  return certificateEligibility;
}

(async () => {
  console.log("Exporting certificate/completion data from Kajabi...\n");
  
  const token = await getToken();
  
  // Try to find certificate endpoints
  const endpointResults = await attemptCertificateExport(token);
  
  console.log("\n=== Endpoint Check Results ===");
  for (const [endpoint, result] of Object.entries(endpointResults)) {
    if (result.success) {
      console.log(`✓ ${endpoint}: Available`);
    } else {
      console.log(`✗ ${endpoint}: ${result.error}`);
    }
  }
  
  // Export completion eligibility from purchase data
  console.log("\n=== Building Certificate Eligibility ===");
  const eligibility = await exportCompletionData(token);
  
  console.log("\n=== Summary ===");
  console.log(`Certificate eligibility records: ${eligibility.length}`);
  console.log(`\nNote: Kajabi's Public API doesn't expose actual certificate issuance data.`);
  console.log(`This export represents users who are eligible for certificates based on enrollments.`);
  console.log(`\nTo get actual certificate data:`);
  console.log(`1. Log into Kajabi dashboard`);
  console.log(`2. Go to Analytics → Certificates`);
  console.log(`3. Export certificate data manually`);
  console.log(`4. Match with this eligibility list using email/course_id`);
  
  console.log(`\n✓ Certificate eligibility exported to: exports/kajabi/certificate_eligibility.ndjson`);
})();



