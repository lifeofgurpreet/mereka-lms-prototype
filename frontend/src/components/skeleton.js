// Component: Skeleton — loading placeholder states
// Usage: import { skeletonCard, skeletonList, skeletonText } from '../components/skeleton.js';

export function skeletonText(lines = 3, widths = null) {
  const ws = widths || Array.from({ length: lines }, (_, i) => i === lines - 1 ? '60%' : '100%');
  return `<div class="skeleton-text" aria-busy="true" aria-label="Loading content">
    ${ws.map(w => `<div class="skeleton-line" style="width:${w};"></div>`).join('')}
  </div>`;
}

export function skeletonCard(count = 3) {
  return `<div class="skeleton-grid" aria-busy="true" aria-label="Loading cards">
    ${Array.from({ length: count }, () => `
      <div class="skeleton-card">
        <div class="skeleton-card__thumb"></div>
        <div class="skeleton-card__body">
          <div class="skeleton-line" style="width:40%;height:12px;"></div>
          <div class="skeleton-line" style="width:80%;height:16px;margin-top:8px;"></div>
          <div class="skeleton-line" style="width:60%;height:12px;margin-top:8px;"></div>
        </div>
      </div>`).join('')}
  </div>`;
}

export function skeletonTable(rows = 5, cols = 4) {
  return `<div class="skeleton-table" aria-busy="true" aria-label="Loading table">
    <div class="skeleton-table__head">
      ${Array.from({ length: cols }, () => `<div class="skeleton-line" style="width:80%;height:12px;"></div>`).join('')}
    </div>
    ${Array.from({ length: rows }, () => `
      <div class="skeleton-table__row">
        ${Array.from({ length: cols }, (_, i) => `<div class="skeleton-line" style="width:${60 + Math.random() * 30}%;height:14px;"></div>`).join('')}
      </div>`).join('')}
  </div>`;
}

export function skeletonKpi(count = 4) {
  return `<div class="skeleton-kpi-row" aria-busy="true">
    ${Array.from({ length: count }, () => `
      <div class="skeleton-kpi">
        <div class="skeleton-line" style="width:50%;height:12px;"></div>
        <div class="skeleton-line" style="width:30%;height:24px;margin-top:8px;"></div>
      </div>`).join('')}
  </div>`;
}
