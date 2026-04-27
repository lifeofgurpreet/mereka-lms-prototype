// Certificates API — Open edX Certificates REST v0
// https://{base}/api/certificates/v0/

import { apiGet } from './client.js';
import { config } from '../config.js';

export async function listMyCertificates(username) {
  if (config.flags.useMockData) {
    return [
      {
        username,
        course_id: 'course-v1:Mereka+DESIGN101+2026',
        course_display_name: 'Design Thinking Foundations',
        certificate_type: 'verified',
        created_date: '2026-02-20T00:00:00Z',
        download_url: '#',
      },
    ];
  }
  return apiGet(`/api/certificates/v0/certificates/${encodeURIComponent(username)}`);
}
