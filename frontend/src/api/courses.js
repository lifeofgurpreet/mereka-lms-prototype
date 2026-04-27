// ---------------------------------------------------------------------------
// Courses API
//
// Talks to the Open edX course discovery endpoints on academyv2.mereka.dev.
// The listing endpoint is fully public (no auth), so the Discover page works
// out of the box against the live backend.
//
// Verified shape (2026-04-24, 41 live courses):
//   { results: [ {
//       id, course_id, name, number, org, short_description,
//       start, start_display, start_type, end,
//       enrollment_start, enrollment_end, effort, pacing,
//       mobile_available, hidden, invitation_only,
//       media: { image: { raw, small, large },
//                banner_image: { uri, uri_absolute },
//                course_image: { uri },
//                course_video: { uri } },
//       blocks_url,
//     }, ... ],
//     pagination: { count, num_pages, next, previous } }
// ---------------------------------------------------------------------------

import { config } from '../config.js';
import { apiGet, ApiError } from './client.js';

/**
 * Normalize an Open edX course record into the shape our UI cards expect.
 * Keeps the raw record on `._raw` for anyone who needs it.
 */
export function normalizeCourse(raw) {
  const media = raw.media || {};
  let image =
    (media.image && (media.image.large || media.image.small || media.image.raw)) ||
    (media.course_image && media.course_image.uri) ||
    (media.banner_image && (media.banner_image.uri_absolute || media.banner_image.uri)) ||
    null;

  // Rewrite absolute image URLs to relative paths so they go through our Netlify proxy.
  // The API returns URLs pointing to academyv2.mereka.dev which 404s for assets;
  // the real assets live on academyv2.mereka.io — our proxy handles the rewrite.
  if (image && /^https?:\/\//.test(image)) {
    try {
      const u = new URL(image);
      image = u.pathname; // e.g. /asset-v1:MEREKA+F101-MS+course+type@asset+block@course_image.jpg
    } catch (_) { /* keep as-is */ }
  }

  return {
    id: raw.course_id || raw.id,
    courseId: raw.course_id || raw.id,
    name: raw.name || raw.display_name || '(Untitled course)',
    number: raw.number || '',
    org: raw.org || '',
    shortDescription: raw.short_description || '',
    start: raw.start || null,
    startDisplay: raw.start_display || null,
    end: raw.end || null,
    pacing: raw.pacing || 'self',
    effort: raw.effort || null,
    image,
    invitationOnly: !!raw.invitation_only,
    mobileAvailable: !!raw.mobile_available,
    blocksUrl: raw.blocks_url || null,
    _raw: raw,
  };
}

/**
 * List courses from the public course discovery API.
 * Supports paging, search, and org filtering — none of which require auth.
 *
 * @param {{ page?: number, pageSize?: number, search?: string, org?: string }} opts
 * @returns {Promise<{ courses, pagination, raw }>}
 */
export async function listCourses(opts = {}) {
  if (config.flags.useMockData) {
    const mocks = await import('./mocks/courses.js');
    return mocks.listCoursesMock(opts);
  }

  const params = new URLSearchParams();
  if (opts.pageSize) params.set('page_size', String(opts.pageSize));
  if (opts.page) params.set('page', String(opts.page));
  if (opts.search) params.set('search_term', opts.search);
  if (opts.org) params.set('org', opts.org);

  const qs = params.toString();
  const path = `/api/courses/v1/courses/${qs ? '?' + qs : ''}`;

  const data = await apiGet(path, { auth: false });
  const results = Array.isArray(data.results) ? data.results : [];
  return {
    courses: results.map(normalizeCourse),
    pagination: data.pagination || { count: results.length, num_pages: 1 },
    raw: data,
  };
}

/** Fetch a single course's public metadata. */
export async function getCourse(courseId) {
  if (config.flags.useMockData) {
    const mocks = await import('./mocks/courses.js');
    return mocks.getCourseMock(courseId);
  }
  const path = `/api/courses/v1/courses/${encodeURIComponent(courseId)}`;
  const data = await apiGet(path, { auth: false });
  return normalizeCourse(data);
}

/**
 * Get the course outline (sections/subsections/units) from the blocks API.
 * Public for most content; private blocks 404 without auth.
 */
export async function getCourseOutline(courseId, opts = {}) {
  const depth = opts.depth || 'all';
  const blockTypes = opts.blockTypes || 'course,chapter,sequential,vertical';
  const params = new URLSearchParams({
    course_id: courseId,
    depth,
    requested_fields: 'display_name,children,student_view_data,lms_web_url,type',
    block_types_filter: blockTypes,
  });
  try {
    return await apiGet(`/api/courses/v2/blocks/?${params.toString()}`, { auth: false });
  } catch (err) {
    if (err instanceof ApiError && err.status === 401) {
      // Fall back to authed request — session may have JWT cookie
      return await apiGet(`/api/courses/v2/blocks/?${params.toString()}`, { auth: true });
    }
    throw err;
  }
}
