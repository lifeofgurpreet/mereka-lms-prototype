// ---------------------------------------------------------------------------
// Programs API
//
// Learning pathways / programs are collections of courses.
// Open edX Programs API is not enabled on this instance, so we serve program
// definitions from a static JSON file (/programs.json) which can later
// be replaced with calls to mereka-backend-v2.
//
// Design notes:
// - 1 course can appear in multiple programs
// - Programs consist only of courses (no experience/expertise in prototype)
// - Future: mereka-backend-v2 will manage creation/editing of programs
// ---------------------------------------------------------------------------

let _cache = null;

/**
 * Fetch all programs. Cached after first load.
 * @returns {Promise<Array>}
 */
export async function listPrograms() {
  if (_cache) return _cache;
  try {
    const res = await fetch('/programs.json');
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    _cache = await res.json();
    return _cache;
  } catch (err) {
    console.warn('[programs] Failed to load programs.json, using empty list:', err.message);
    return [];
  }
}

/**
 * Get a single program by ID.
 * @param {string} programId
 * @returns {Promise<Object|null>}
 */
export async function getProgram(programId) {
  const all = await listPrograms();
  return all.find(p => p.id === programId) || null;
}

/**
 * Get all programs that contain a given course ID.
 * @param {string} courseId
 * @returns {Promise<Array>}
 */
export async function getProgramsForCourse(courseId) {
  const all = await listPrograms();
  return all.filter(p => p.courses.includes(courseId));
}

/**
 * Invalidate the cache (for admin editing scenarios).
 */
export function invalidateCache() {
  _cache = null;
}
