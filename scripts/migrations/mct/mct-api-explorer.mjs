#!/usr/bin/env node

/**
 * MCT API Explorer - Documents all endpoints from Swagger UI
 * 
 * This script systematically explores the MCT API to document all available endpoints
 * across V1, V2, V3, and V4.
 * 
 * Usage:
 *   MCT_BASE_URL=learn.skillourfuture.org \
 *   MCT_API_URI=api://e8edea94-e86f-4dc7-857e-3c5c09bb76d3 \
 *   MCT_CLIENT_ID=<client-id> \
 *   MCT_CLIENT_SECRET=<client-secret> \
 *   MCT_TENANT_ID=<tenant-id> \
 *   node scripts/migrations/mct/mct-api-explorer.mjs
 */

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const MCT_BASE_URL = process.env.MCT_BASE_URL?.replace(/^https?:\/\//, "").replace(/\/$/, "") || "learn.skillourfuture.org";
const MCT_API_URI = process.env.MCT_API_URI;
const MCT_CLIENT_ID = process.env.MCT_CLIENT_ID;
const MCT_CLIENT_SECRET = process.env.MCT_CLIENT_SECRET;
const MCT_TENANT_ID = process.env.MCT_TENANT_ID;

if (!MCT_CLIENT_ID || !MCT_CLIENT_SECRET || !MCT_TENANT_ID || !MCT_API_URI) {
  console.error("Missing required environment variables:");
  console.error("  MCT_CLIENT_ID, MCT_CLIENT_SECRET, MCT_TENANT_ID, MCT_API_URI");
  process.exit(1);
}

const API_BASE = `https://${MCT_BASE_URL}/api`;
const OUTPUT_DIR = path.resolve("./docs/migrations/mct/api-endpoints");

fs.mkdirSync(OUTPUT_DIR, { recursive: true });

// Get authentication token
async function getToken() {
  const tokenEndpoint = `https://login.microsoft.com/${MCT_TENANT_ID}/oauth2/v2.0/token`;
  const data = `grant_type=client_credentials&client_id=${encodeURIComponent(
    MCT_CLIENT_ID
  )}&scope=${encodeURIComponent(
    `${MCT_API_URI}/.default`
  )}&client_secret=${encodeURIComponent(MCT_CLIENT_SECRET)}`;

  const response = await fetch(tokenEndpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      "Content-Length": Buffer.byteLength(data).toString(),
    },
    body: data,
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Token request failed [${response.status}]: ${text}`);
  }

  const tokenData = await response.json();
  if (!tokenData.access_token) {
    throw new Error("No access token in response");
  }

  return tokenData.access_token;
}

// Try to fetch Swagger JSON
async function fetchSwaggerJson(version) {
  const urls = [
    `${API_BASE.replace("/api", "")}/swagger/${version}/swagger.json`,
    `${API_BASE.replace("/api", "")}/swagger/v${version}/swagger.json`,
    `${API_BASE.replace("/api", "")}/swagger/${version}.json`,
  ];

  const token = await getToken();

  for (const url of urls) {
    try {
      const response = await fetch(url, {
        headers: {
          Authorization: `Bearer ${token}`,
          ClientType: "service",
        },
      });

      if (response.ok) {
        const json = await response.json();
        return json;
      }
    } catch (error) {
      // Try next URL
      continue;
    }
  }

  return null;
}

// Extract endpoints from Swagger JSON
function extractEndpoints(swaggerJson) {
  if (!swaggerJson || !swaggerJson.paths) {
    return [];
  }

  const endpoints = [];
  for (const [path, methods] of Object.entries(swaggerJson.paths)) {
    for (const [method, details] of Object.entries(methods)) {
      if (typeof details === "object" && details !== null) {
        endpoints.push({
          path,
          method: method.toUpperCase(),
          summary: details.summary || "",
          description: details.description || "",
          tags: details.tags || [],
          parameters: details.parameters || [],
          responses: details.responses || {},
        });
      }
    }
  }
  return endpoints;
}

// Group endpoints by tag/category
function groupEndpoints(endpoints) {
  const grouped = {};
  for (const endpoint of endpoints) {
    const tag = endpoint.tags[0] || "Other";
    if (!grouped[tag]) {
      grouped[tag] = [];
    }
    grouped[tag].push(endpoint);
  }
  return grouped;
}

// Generate markdown documentation
function generateMarkdown(version, swaggerJson, endpoints) {
  const grouped = groupEndpoints(endpoints);
  const tags = Object.keys(grouped).sort();

  let md = `# MCT API V${version.toUpperCase()} - Complete Endpoint Reference\n\n`;
  md += `**Generated:** ${new Date().toISOString()}\n`;
  md += `**Base URL:** ${API_BASE}/${version}\n\n`;

  if (swaggerJson.info) {
    md += `**API Info:**\n`;
    md += `- Title: ${swaggerJson.info.title || "N/A"}\n`;
    md += `- Version: ${swaggerJson.info.version || "N/A"}\n`;
    md += `- Description: ${swaggerJson.info.description || "N/A"}\n\n`;
  }

  md += `## Endpoints by Category\n\n`;

  for (const tag of tags) {
    md += `### ${tag}\n\n`;
    for (const endpoint of grouped[tag]) {
      md += `#### \`${endpoint.method} ${endpoint.path}\`\n\n`;
      if (endpoint.summary) {
        md += `**Summary:** ${endpoint.summary}\n\n`;
      }
      if (endpoint.description) {
        md += `${endpoint.description}\n\n`;
      }
      if (endpoint.parameters && endpoint.parameters.length > 0) {
        md += `**Parameters:**\n`;
        for (const param of endpoint.parameters) {
          md += `- \`${param.name}\` (${param.in || "query"}): ${param.description || ""} ${param.required ? "**[Required]**" : ""}\n`;
        }
        md += `\n`;
      }
      md += `---\n\n`;
    }
  }

  return md;
}

// Main execution
(async () => {
  console.log("MCT API Explorer");
  console.log("=".repeat(60));
  console.log(`Base URL: ${MCT_BASE_URL}`);
  console.log(`Output: ${OUTPUT_DIR}`);
  console.log("=".repeat(60));

  const versions = ["v1", "v2", "v3", "v4"];

  for (const version of versions) {
    console.log(`\n[${version}] Fetching Swagger JSON...`);
    const swaggerJson = await fetchSwaggerJson(version);

    if (!swaggerJson) {
      console.log(`[${version}] ⚠️  Swagger JSON not accessible via API`);
      console.log(`[${version}]    Try accessing manually: https://${MCT_BASE_URL}/swagger/index.html?urls.primaryName=${version.toUpperCase()}`);
      continue;
    }

    console.log(`[${version}] ✓ Swagger JSON fetched`);
    const endpoints = extractEndpoints(swaggerJson);
    console.log(`[${version}] ✓ Found ${endpoints.length} endpoints`);

    // Save raw JSON
    const jsonPath = path.join(OUTPUT_DIR, `${version}-swagger.json`);
    fs.writeFileSync(jsonPath, JSON.stringify(swaggerJson, null, 2));
    console.log(`[${version}] ✓ Saved raw JSON to ${jsonPath}`);

    // Generate and save markdown
    const md = generateMarkdown(version, swaggerJson, endpoints);
    const mdPath = path.join(OUTPUT_DIR, `${version}-endpoints.md`);
    fs.writeFileSync(mdPath, md);
    console.log(`[${version}] ✓ Generated documentation: ${mdPath}`);

    // Save endpoints list
    const endpointsPath = path.join(OUTPUT_DIR, `${version}-endpoints.json`);
    fs.writeFileSync(endpointsPath, JSON.stringify(endpoints, null, 2));
    console.log(`[${version}] ✓ Saved endpoints list: ${endpointsPath}`);
  }

  console.log("\n" + "=".repeat(60));
  console.log("Exploration Complete!");
  console.log("=".repeat(60));
  console.log(`\nOutput directory: ${OUTPUT_DIR}`);
  console.log("\nNext steps:");
  console.log("1. Review generated documentation");
  console.log("2. Manually explore Swagger UI for any missing endpoints");
  console.log("3. Update API_COMPLETE_REFERENCE.md with findings");
})();

