#!/usr/bin/env node
/**
 * Test various Kajabi API endpoints for certificate/completion data
 * 
 * This script tests endpoints to verify what's actually available.
 * See docs/KAJABI_API_ENDPOINTS.md for the official list of available endpoints.
 */

import { readFileSync } from "fs";
import { join } from "path";

const API = "https://api.kajabi.com";
const CLIENT_ID = process.env.KAJABI_CLIENT_ID || process.env.KAJABI_API_KEY;
const CLIENT_SECRET = process.env.KAJABI_CLIENT_SECRET;

if (!CLIENT_ID || !CLIENT_SECRET) {
  console.error("Missing KAJABI_CLIENT_ID or KAJABI_CLIENT_SECRET");
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
  const json = await res.json();
  return json.access_token;
}

async function testEndpoint(token, endpoint, description) {
  try {
    const url = `${API}${endpoint}`;
    const res = await fetch(url, {
      headers: { Authorization: `Bearer ${token}` },
    });
    
    const contentType = res.headers.get("content-type") || "";
    const isJson = contentType.includes("application/json");
    
    if (res.ok) {
      if (isJson) {
        const data = await res.json();
        return {
          success: true,
          status: res.status,
          hasData: !!data,
          keys: data ? Object.keys(data).slice(0, 10) : [],
          sample: JSON.stringify(data).substring(0, 200),
        };
      } else {
        const text = await res.text();
        return {
          success: false,
          status: res.status,
          error: `Not JSON (got ${contentType})`,
          preview: text.substring(0, 100),
        };
      }
    } else {
      const text = await res.text().catch(() => "");
      return {
        success: false,
        status: res.status,
        error: res.statusText,
        preview: text.substring(0, 100) || "",
      };
    }
  } catch (err) {
    return {
      success: false,
      error: err.message,
    };
  }
}

// Get sample IDs from exports
function getSampleIds() {
  const productsFile = join(process.cwd(), "exports/kajabi/products.ndjson");
  const customersFile = join(process.cwd(), "exports/kajabi/customers.ndjson");
  const purchasesFile = join(process.cwd(), "exports/kajabi/purchases.ndjson");

  let productId = null;
  let customerId = null;
  let purchaseId = null;

  try {
    const products = readFileSync(productsFile, "utf-8")
      .split("\n")
      .filter(Boolean);
    if (products.length > 0) {
      productId = JSON.parse(products[0]).id;
    }
  } catch (e) {
    // ignore
  }

  try {
    const customers = readFileSync(customersFile, "utf-8")
      .split("\n")
      .filter(Boolean);
    if (customers.length > 0) {
      customerId = JSON.parse(customers[0]).id;
    }
  } catch (e) {
    // ignore
  }

  try {
    const purchases = readFileSync(purchasesFile, "utf-8")
      .split("\n")
      .filter(Boolean);
    if (purchases.length > 0) {
      purchaseId = JSON.parse(purchases[0]).id;
    }
  } catch (e) {
    // ignore
  }

  return { productId, customerId, purchaseId };
}

async function main() {
  console.log("Testing Kajabi API endpoints for certificate/completion data...\n");
  
  const token = await getToken();
  const { productId, customerId, purchaseId } = getSampleIds();

  console.log(`Using sample IDs:`);
  console.log(`  Product: ${productId}`);
  console.log(`  Customer: ${customerId}`);
  console.log(`  Purchase: ${purchaseId}\n`);

  const endpoints = [
    // Generic endpoints
    { path: "/v1/certificates", desc: "Generic certificates endpoint" },
    { path: "/v1/completions", desc: "Generic completions endpoint" },
    { path: "/v1/course_completions", desc: "Course completions endpoint" },
    { path: "/v1/achievements", desc: "Achievements endpoint" },
    
    // Product-specific endpoints
    ...(productId ? [
      { path: `/v1/products/${productId}/certificates`, desc: "Product certificates" },
      { path: `/v1/products/${productId}/completions`, desc: "Product completions" },
      { path: `/v1/products/${productId}/students`, desc: "Product students" },
      { path: `/v1/products/${productId}/enrollments`, desc: "Product enrollments" },
    ] : []),
    
    // Customer-specific endpoints
    ...(customerId ? [
      { path: `/v1/customers/${customerId}/certificates`, desc: "Customer certificates" },
      { path: `/v1/customers/${customerId}/completions`, desc: "Customer completions" },
    ] : []),
    
    // Purchase-specific endpoints
    ...(purchaseId ? [
      { path: `/v1/purchases/${purchaseId}/certificates`, desc: "Purchase certificates" },
    ] : []),
  ];

  const results = [];
  
  for (const { path, desc } of endpoints) {
    process.stderr.write(`Testing ${path}... `);
    const result = await testEndpoint(token, path, desc);
    results.push({ path, desc, ...result });
    
    if (result.success) {
      console.log(`✓ ${result.status} - Found data!`);
      console.log(`  Keys: ${result.keys.join(", ")}`);
      console.log(`  Sample: ${result.sample}...`);
    } else {
      console.log(`✗ ${result.status || result.error}`);
    }
  }

  console.log("\n" + "=".repeat(60));
  console.log("SUMMARY");
  console.log("=".repeat(60));
  
  const successful = results.filter(r => r.success);
  if (successful.length > 0) {
    console.log(`\n✓ Found ${successful.length} working endpoint(s):`);
    successful.forEach(r => {
      console.log(`  ${r.path} - ${r.desc}`);
    });
  } else {
    console.log("\n✗ No certificate/completion endpoints found in Kajabi Public API");
    console.log("\nVerdict: Certificate data is NOT available via the Kajabi Public API.");
    console.log("\nAlternative options:");
    console.log("  1. Manual export from Kajabi dashboard (Analytics → Certificates)");
    console.log("  2. Use enrollment/purchase data as proxy for certificate eligibility");
    console.log("  3. Check if Kajabi has a private/internal API (requires support ticket)");
  }
}

main().catch(console.error);

