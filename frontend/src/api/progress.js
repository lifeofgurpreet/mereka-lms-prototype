// Progress API — Open edX Course Home REST v1 + Completion v1
// https://{base}/api/course_home/v1/ + /api/completion/v1/

import { apiGet, apiPost } from './client.js';
import { config } from '../config.js';

export async function getCourseProgress(courseId) {
  if (config.flags.useMockData) {
    return { completion: { complete: 4, total: 12 }, course_grade: { percent: 0.65 } };
  }
  return apiGet(`/api/course_home/v1/progress/${encodeURIComponent(courseId)}/`);
}

export async function getCourseDates(courseId) {
  if (config.flags.useMockData) {
    return { course_date_blocks: [] };
  }
  return apiGet(`/api/course_home/v1/dates/${encodeURIComponent(courseId)}`);
}

/** Mark a block (unit or sub-block) as complete. */
export async function markComplete(blockKey) {
  return apiPost('/api/completion/v1/completion-batch/', {
    body: { username: null, course_key: null, blocks: { [blockKey]: 1.0 } },
  });
}
