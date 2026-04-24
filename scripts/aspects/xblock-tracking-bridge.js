/**
 * XBlock → MFE Tracking Event Bridge
 *
 * Architecture:
 *   XBlock iframe (chromeless view) → postMessage → parent MFE → sendTrackingLogEvent → LMS /event
 *
 * This script runs INSIDE the XBlock iframe (chromeless courseware view).
 * It intercepts Logger.log() calls and forwards them to the parent MFE
 * via postMessage, using the same pattern as the existing resize bridge.
 *
 * The parent MFE (frontend-app-learning) listens for these messages and
 * dispatches them through @edx/frontend-platform's sendTrackingLogEvent,
 * which POSTs to the LMS /event endpoint with proper auth.
 *
 * Installation:
 *   Option A: Tutor plugin patch — inject this script into the chromeless template
 *   Option B: Custom env.config.js — add a message listener in the MFE shell
 *
 * This bridge is intentionally narrow and deletable. When Open edX moves
 * video XBlocks out of edx-platform, this bridge becomes unnecessary.
 */

// === IFRAME SIDE (runs inside chromeless XBlock view) ===
(function() {
  'use strict';

  // Only activate inside an iframe (MFE XBlock render)
  if (window === window.parent) return;

  // Only activate if Logger exists (it should, via lms-application.js)
  if (typeof window.Logger === 'undefined') return;

  // Wrap Logger.log to also forward events to parent MFE
  var originalLog = window.Logger.log;

  window.Logger.log = function(eventType, data, element, requestOptions) {
    // Forward to parent MFE via postMessage
    try {
      window.parent.postMessage({
        type: 'plugin.trackingEvent',
        payload: {
          eventType: eventType,
          data: data || {},
          timestamp: new Date().toISOString(),
        }
      }, document.referrer || '*');
    } catch (e) {
      // Don't let bridge errors break the original tracking
    }

    // Still call the original Logger.log (which POSTs to /event directly)
    return originalLog.call(this, eventType, data, element, requestOptions);
  };
})();


// === PARENT MFE SIDE (runs in frontend-app-learning) ===
// This would go in env.config.js or a custom plugin:
//
// window.addEventListener('message', function(event) {
//   if (event.data && event.data.type === 'plugin.trackingEvent') {
//     var payload = event.data.payload;
//     // Dispatch through frontend-platform analytics
//     import('@edx/frontend-platform/analytics').then(function(analytics) {
//       analytics.sendTrackingLogEvent(payload.eventType, payload.data);
//     });
//   }
// });
