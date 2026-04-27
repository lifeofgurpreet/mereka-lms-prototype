// Enrollment API — Open edX Enrollment REST v1
// https://{base}/api/enrollment/v1/

import { apiGet, apiPost } from './client.js';
import { config } from '../config.js';
import { mockEnrollments } from './mocks/enrollment.js';

export async function listMyEnrollments() {
  if (config.flags.useMockData) return mockEnrollments();
  return apiGet('/api/enrollment/v1/enrollment');
}

export async function getEnrollment(username, courseId) {
  if (config.flags.useMockData) {
    return mockEnrollments().find((e) => e.course_id === courseId) ?? null;
  }
  return apiGet(
    `/api/enrollment/v1/enrollment/${encodeURIComponent(username)},${encodeURIComponent(courseId)}`,
  );
}

export async function enroll(courseId, mode = 'audit') {
  return apiPost('/api/enrollment/v1/enrollment', {
    body: { course_details: { course_id: courseId }, mode },
  });
}
