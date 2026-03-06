# Observability /metrics payload evidence

- component: LMS
- generated_at: 2026-03-03T04:11:48Z
- status_code: 404
- metric_path: /metrics
- payload_bytes: 11560
- help_count: 0
- type_count: 0
- numeric_sample_count: 0
- evidence_identity: env=nonprod;profile=nonprod;context=rke2-nonprod;project=mereka-lms

## Payload sample

```text
<!DOCTYPE html>
<!--[if lte IE 9]><html class="ie ie9 lte9" lang="en"><![endif]-->
<!--[if !IE]><!--><html lang="en"><!--<![endif]-->
<head dir="ltr">
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>
       Page Not Found | Mereka Academy
      </title>
      <script type="text/javascript">
        /* immediately break out of an iframe if coming from the marketing website */
        (function(window) {
          if (window.location !== window.top.location) {
            window.top.location = window.location;
          }
        })(this);
      </script>
  <script type="text/javascript" src="/static/js/i18n/en/djangojs.js"></script>
  <script type="text/javascript" src="/static/js/ie11_find_array.67b5a9edd5d5.js"></script>
  <link rel="icon" type="image/x-icon" href="/static/images/favicon.03ffbbf95a0d.ico"/>
    <link href="/static/css/lms-style-vendor.68e48093f5dd.css" rel="stylesheet" type="text/css" />
    <link href="/static/css/lms-main-v1.2118a8b4c589.css" rel="stylesheet" type="text/css" />
<script type="text/javascript" src="/static/js/lms-main_vendor.eb0860655612.js" charset="utf-8"></script>
<script type="text/javascript" src="/static/js/lms-application.11f6cc46716f.js" charset="utf-8"></script>
    <script type="text/javascript" src="/static/bundles/commons.20bdac4aef0c44b02b02.0aec685f1bf4.js" ></script>
  <script>
    window.baseUrl = "/static/";
    (function (require) {
      require.config({
          baseUrl: window.baseUrl
      });
    }).call(this, require || RequireJS.require);
  </script>
  <script type="text/javascript" src="/static/lms/js/require-config.dc07836174b8.js"></script>
    <script type="text/javascript">
        (function (require) {
          require.config({
              paths: {
                'course_bookmarks/js/views/bookmark_button': 'course_bookmarks/js/views/bookmark_button.5192bfbedbfb',
'js/views/message_banner': 'js/views/message_banner.141974fd4f5d',
'moment': 'common/js/vendor/moment-with-locales.d07131713d35',
'moment-timezone': 'common/js/vendor/moment-timezone-with-data.6741dd44cec2',
'js/courseware/course_info_events': 'js/courseware/course_info_events.2fc35b57627f',
'js/courseware/accordion_events': 'js/courseware/accordion_events.6064c7809de5',
'js/dateutil_factory': 'js/dateutil_factory.05baa90549aa',
'js/courseware/link_clicked_events': 'js/courseware/link_clicked_events',
'js/courseware/toggle_element_visibility': 'js/courseware/toggle_element_visibility.474ff5ba9de3',
'js/student_account/logistration_factory': 'js/student_account/logistration_factory.df4e41783d02',
'js/courseware/courseware_factory': 'js/courseware/courseware_factory.1504fc10caef',
'js/groups/views/cohorts_dashboard_factory': 'js/groups/views/cohorts_dashboard_factory.f9c69d089f31',
'js/groups/discussions_management/discussions_dashboard_factory': 'js/discussions_management/views/discussions_dashboard_factory.2e10d9097343',
'draggabilly': 'js/vendor/draggabilly.26caba6f7187',
'hls': 'common/js/vendor/hls.3026d7d10201'
            }
          });
        }).call(this, require || RequireJS.require);
    </script>
<script type="application/json" id="user-metadata">
    null
</script>
<link
  rel="preload"
  as="font"
  type="font/woff2"
  crossorigin
  href="/static/fonts/Poppins-Regular.woff2"
/>
<link
  rel="preload"
  as="font"
  type="font/woff2"
  crossorigin
  href="/static/fonts/Lato-Regular.woff2"
/>
<link
  rel="stylesheet"
  href="/static/css/mereka-overrides.css"
  type="text/css"
  media="all"
/>
<style id="mereka-course-card-hotfix">
  .courses-listing li,
  .courses-listing-item,
  .dashboard .listing-courses li {
    display: flex;
    min-width: 0;
  }
  .courses-listing li > .course,
  .courses-listing-item > .course,
  .dashboard .listing-courses li .course {
    display: flex;
    flex-direction: column;
    width: 100%;
    min-height: 100%;
  }
  /* Learner dashboard: consistent spacing + non-squashed list cards */
  .dashboard .listing-courses {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
    gap: 1.5rem;
    margin: 0;
    padding: 0;
  }
  .dashboard .my-courses .listing-courses {
    display: flex;
    flex-direction: column;
    /* Avoid relying on flex-gap (inconsistent on older Safari builds). */
  }
  .dashboard .my-courses .listing-courses > * + * {
    margin-top: 1.25rem;
  }
  .dashboard .my-courses .course-item {
    margin: 0;
    width: 100%;
  }
  .dashboard .my-courses .course-item .course {
    display: flex;
    align-items: stretch;
    min-height: 200px;
    border-radius: 28px;
    border: 1px solid rgba(26, 22, 35, 0.08);
    overflow: hidden;
    background: #fff;
  }
  .dashboard .my-courses .course-item .wrapper-course-image {
    flex: 0 0 clamp(220px, 34%, 360px);
    max-width: 360px;
    margin: 0;
  }
  .dashboard .my-courses .course-item .wrapper-course-image a,
  .dashboard .my-courses .course-item .course-image,
  .dashboard .my-courses .course-item .course-image .cover-image {
    display: block;
    height: 100%;
  }
  .dashboard .my-courses .course-item .wrapper-course-image img {
    display: block;
    width: 100%;
    height: 100%;
    object-fit: cover;
    object-position: center;
  }
  @media (max-width: 992px) {
    .dashboard .my-courses .course-item .course {
      flex-direction: column;
      min-height: 0;
    }
    .dashboard .my-courses .course-item .wrapper-course-image {
      flex: 0 0 auto;
      max-width: none;
    }
    .dashboard .my-courses .course-item .course-image,
    .dashboard .my-courses .course-item .course-image .cover-image,
    .dashboard .my-courses .course-item .wrapper-course-image img {
      height: 200px;
    }
  }
  .course .course-image,
  .dashboard .course .course-image {
    min-height: 180px;
    background: linear-gradient(135deg, rgba(45, 137, 139, 0.22), rgba(41, 92, 173, 0.25));
  }
  .course .course-image .cover-image,
  .dashboard .course .course-image .cover-image {
    height: 180px;
    min-height: 180px;
    background: inherit;
  }
  .course .course-image img,
  .dashboard .course .course-image img {
    display: block;
    height: 180px;
    width: 100%;
    object-fit: cover;
    object-position: center;
  }
  .course .course-info {
    display: flex;
    flex-direction: column;
    gap: 0.45rem;
  }
</style>
<!-- dummy Segment -->
<script type="text/javascript">
  var analytics = {
    track: function() { return; },
    trackLink: function() { return; },
    pageview: function() { return; },
    page: function() { return; }
  };
</script>
<!-- end dummy Segment -->
  <meta name="path_prefix" content="">
  <meta name="openedx-release-line" content="redwood" />
</head>
<body class="ltr  lang_en">
<div id="page-prompt"></div>
  <div class="window-wrap" dir="ltr">
    <a class="nav-skip sr-only sr-only-focusable" href="#main">Skip to main content</a>
```
