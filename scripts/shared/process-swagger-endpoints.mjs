#!/usr/bin/env node

/**
 * Process extracted Swagger endpoints and generate documentation
 */

import fs from 'node:fs';
import path from 'node:path';

// This will be populated from browser extraction
const ENDPOINTS_DATA = {};

// Generate markdown from endpoints data
function generateMarkdown(data) {
  let md = `# MCT API V1 - Complete Endpoint Reference\n\n`;
  md += `**Source:** Swagger UI exploration\n`;
  md += `**Date:** 2025-11-07\n`;
  md += `**Total Sections:** ${data.totalSections}\n`;
  md += `**Total Endpoints:** ${data.totalEndpoints}\n`;
  md += `**Base URL:** \`https://learn.skillourfuture.org/api/v1\`\n\n`;
  md += `---\n\n`;

  // Sort sections alphabetically
  const sections = Object.keys(data.sections).sort();
  
  for (const tag of sections) {
    const endpoints = data.sections[tag];
    md += `## ${tag}\n\n`;
    md += `**Endpoints:** ${endpoints.length}\n\n`;
    
    for (const ep of endpoints) {
      md += `### \`${ep.method} ${ep.path}\`\n\n`;
      if (ep.summary) {
        md += `${ep.summary}\n\n`;
      }
      md += `---\n\n`;
    }
  }
  
  return md;
}

// Save to file
const outputPath = path.resolve('./docs/reference/migrations/mct/api-endpoints/V1_COMPLETE.md');
console.log(`Will write to: ${outputPath}`);

export { generateMarkdown };

