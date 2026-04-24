// Courses API — Open edX Courses REST v1
// https://{base}/api/courses/v1/

import { apiGet } from './client.js';
import { config } from '../config.js';
import { mockCourses, mockCourse } from './mocks/courses.js';

/** List courses with optional filters. */
export async function listCourses({ search, org, language, pageSize = 24 } = {}) {
  if (config.flags.useMockData) return mockCourses();
  return apiGet('/api/courses/v1/courses/', {
    query: { search_term: search, org, language, page_size: pageSize },
  });
}

/** Get course detail by course_id (e.g. "course-v1:Mereka+DESIGN101+2026"). */
export async function getCourse(courseId) {
  if (config.flags.useMockData) return mockCourse(courseId);
  return apiGet(`/api/courses/v1/courses/${encodeURIComponent(courseId)}`);
}

/** Get course outline (modules, units) — for course detail and player. */
export async function getCourseOutline(courseId) {
  if (config.flags.useMockData) return mockCourse(courseId).outline;
  return apiGet(`/api/course_home/v1/outline/${encodeURIComponent(courseId)}`);
}
