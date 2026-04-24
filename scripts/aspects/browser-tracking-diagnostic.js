/**
 * Browser Tracking Diagnostic for Mereka LMS
 *
 * Paste this into the browser console on any course page
 * (academyv2.mereka.io or academyv2.mereka.dev) to diagnose
 * why video tracking events aren't reaching ClickHouse.
 *
 * Reports: Logger availability, /event endpoint, CSRF setup,
 * completion service, and attempts a test event.
 */
(function() {
  const results = {};

  // 1. Check Logger availability
  results.logger = {
    windowLogger: typeof window.Logger,
    loggerLog: typeof window.Logger?.log,
    loggerBind: typeof window.Logger?.bind,
  };

  // 2. Check if we're in an iframe (MFE XBlock render)
  results.context = {
    inIframe: window !== window.parent,
    isLearningMFE: document.body.classList.contains('view-in-mfe'),
    hasCourseContent: !!document.getElementById('course-content'),
    completionOnView: document.getElementById('course-content')?.dataset?.enableCompletionOnViewService,
  };

  // 3. Check CSRF token availability
  const csrfCookie = document.cookie.split(';')
    .map(c => c.trim())
    .find(c => c.startsWith('csrftoken='));
  results.csrf = {
    hasCsrfCookie: !!csrfCookie,
    csrfTokenLength: csrfCookie ? csrfCookie.split('=')[1].length : 0,
  };

  // 4. Check jQuery availability (Logger depends on it)
  results.jquery = {
    available: typeof window.$ !== 'undefined',
    version: typeof window.$?.fn?.jquery,
    ajaxWithPrefix: typeof window.$?.ajaxWithPrefix,
  };

  // 5. Check RequireJS
  results.requirejs = {
    available: typeof window.require !== 'undefined',
    defined: typeof window.requirejs !== 'undefined',
  };

  // 6. Try to POST a test event to /event
  const testEvent = async () => {
    try {
      const csrfToken = csrfCookie ? csrfCookie.split('=')[1] : '';
      const resp = await fetch('/event', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'X-CSRFToken': csrfToken,
        },
        credentials: 'include',
        body: new URLSearchParams({
          event_type: 'test.browser.diagnostic',
          event: JSON.stringify({ diagnostic: true, timestamp: new Date().toISOString() }),
          page: window.location.pathname,
        }),
      });
      results.eventEndpoint = {
        status: resp.status,
        ok: resp.ok,
        statusText: resp.statusText,
      };
    } catch (e) {
      results.eventEndpoint = { error: e.message };
    }
  };

  // 7. If Logger exists, try Logger.log directly
  const testLogger = () => {
    if (window.Logger && typeof window.Logger.log === 'function') {
      try {
        window.Logger.log('test.diagnostic', { diagnostic: true });
        results.loggerTest = 'SUCCESS - Logger.log() called without error';
      } catch (e) {
        results.loggerTest = `FAILED - ${e.message}`;
      }
    } else {
      results.loggerTest = 'SKIPPED - Logger not available';
    }
  };

  testLogger();
  testEvent().then(() => {
    console.log('=== Mereka LMS Tracking Diagnostic ===');
    console.table(results.logger);
    console.log('Context:', results.context);
    console.log('CSRF:', results.csrf);
    console.log('jQuery:', results.jquery);
    console.log('RequireJS:', results.requirejs);
    console.log('Event endpoint test:', results.eventEndpoint);
    console.log('Logger.log test:', results.loggerTest);
    console.log('');

    // Summary
    const issues = [];
    if (results.logger.windowLogger === 'undefined') issues.push('❌ window.Logger is undefined');
    if (!results.csrf.hasCsrfCookie) issues.push('❌ No CSRF cookie');
    if (!results.jquery.available) issues.push('❌ jQuery not available');
    if (results.eventEndpoint?.status === 403) issues.push('⚠️  /event returned 403 (CSRF issue?)');
    if (results.eventEndpoint?.error) issues.push('❌ /event fetch failed: ' + results.eventEndpoint.error);
    if (results.context.inIframe) issues.push('ℹ️  Running inside iframe (MFE XBlock render)');

    if (issues.length === 0) {
      console.log('✅ All checks passed — tracking should work');
    } else {
      console.log('Issues found:');
      issues.forEach(i => console.log('  ' + i));
    }
    console.log('=== End Diagnostic ===');
  });
})();
