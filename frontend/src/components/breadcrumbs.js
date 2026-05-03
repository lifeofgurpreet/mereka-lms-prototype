// Component: Breadcrumbs — contextual navigation for course player
import { navigate } from '../router/router.js';

/**
 * Render breadcrumbs bar.
 * @param {object} opts
 * @param {string} opts.courseName
 * @param {string} opts.courseId
 * @param {string} [opts.moduleName]
 * @param {string} [opts.unitName]
 */
export function renderBreadcrumbs({ courseName, courseId, moduleName, unitName }) {
  const crumbs = [
    { label: 'My Learning', path: '/my-learning' },
    { label: courseName || 'Course', path: `/course/${courseId || 'demo'}` },
  ];
  if (moduleName) crumbs.push({ label: moduleName, path: null });
  if (unitName) crumbs.push({ label: unitName, path: null });

  return `
  <nav class="breadcrumbs" aria-label="Breadcrumb">
    <ol class="breadcrumbs__list">
      ${crumbs.map((c, i) => `
        <li class="breadcrumbs__item ${i === crumbs.length - 1 ? 'is-current' : ''}">
          ${c.path && i < crumbs.length - 1
            ? `<a href="${c.path}" class="breadcrumbs__link">${esc(c.label)}</a>`
            : `<span aria-current="${i === crumbs.length - 1 ? 'page' : ''}">${esc(c.label)}</span>`}
          ${i < crumbs.length - 1 ? '<span class="breadcrumbs__sep" aria-hidden="true">›</span>' : ''}
        </li>`).join('')}
    </ol>
  </nav>`;
}

function esc(s) { return (s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }

export function wireBreadcrumbs(rootEl) {
  rootEl.querySelectorAll('.breadcrumbs__link').forEach(a => {
    a.addEventListener('click', e => {
      e.preventDefault();
      navigate(a.getAttribute('href'));
    });
  });
}
