# Observability /metrics payload evidence

- component: CMS
- generated_at: 2026-03-03T04:11:48Z
- status_code: 404
- metric_path: /metrics
- payload_bytes: 5946
- help_count: 0
- type_count: 0
- numeric_sample_count: 0
- evidence_identity: env=nonprod;profile=nonprod;context=rke2-nonprod;project=mereka-lms

## Payload sample

```text
<!doctype html>
<!--[if lte IE 9]><html class="ie9 lte9" lang="en"><![endif]-->
<!--[if !IE]><<!--><html lang="en"><!--<![endif]-->
  <head dir="ltr">
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1">
    <meta name="openedx-release-line" content="redwood" />
    <title>
        Page Not Found |
        Mereka Academy - Studio
    </title>
    <script type="text/javascript" src="/static/studio/js/i18n/en/djangojs.js"></script>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <meta name="path_prefix" content="">
    <link rel="icon" type="image/x-icon" href="/static/studio/images/favicon.ico"/>
    <link href="/static/studio/css/cms-style-vendor.0bb1c51e34bf.css" rel="stylesheet" type="text/css" />
    <link href="/static/studio/css/cms-style-vendor-tinymce-content.fccb74b96a2f.css" rel="stylesheet" type="text/css" />
    <link href="/static/studio/css/cms-style-vendor-tinymce-skin.8a6209be4588.css" rel="stylesheet" type="text/css" />
    <link href="/static/studio/css/studio-main-v1.5cedc7d98b79.css" rel="stylesheet" type="text/css" />
<!-- dummy Segment -->
<script type="text/javascript">
  var analytics = {
    "track": function() {}
  };
</script>
<!-- end dummy Segment -->
    <!-- Hotjar Tracking Code for studio -->
    <script>
      (function(h,o,t,j,a,r){
          h.hj=h.hj||function(){(h.hj.q=h.hj.q||[]).push(arguments)};
          h._hjSettings={hjid: Number("0"),hjsv:6};
          a=o.getElementsByTagName('head')[0];
          r=o.createElement('script');r.async=1;
          r.src=t+h._hjSettings.hjid+j+h._hjSettings.hjsv;
          a.appendChild(r);
      })(window,document,'https://static.hotjar.com/c/hotjar-','.js?sv=');
    </script>
  </head>
  <body class="ltr view-util util-404 lang_en">
    <a class="nav-skip" href="#main">Skip to main content</a>
<script type="text/javascript" src="/static/studio/js/cms-base-vendor.5fa9e818ccd4.js" charset="utf-8"></script>
    <script type="text/javascript" src="/static/studio/bundles/commons.20bdac4aef0c44b02b02.0aec685f1bf4.js" ></script>
    <script type="text/javascript">
      window.baseUrl = "/static/studio/";
      require.config({
          baseUrl: window.baseUrl
      });
    </script>
    <script type="text/javascript" src="/static/studio/cms/js/require-config.b38938f98900.js"></script>
    <!-- view -->
    <div class="wrapper wrapper-view" dir="ltr">
<div class="wrapper-header wrapper" id="view-top">
  <header class="primary" role="banner">
    <div class="wrapper wrapper-l">
      <h1 class="branding">
        <a class="brand-link" href="/">
          <img class="brand-image" src="/static/studio/images/studio-logo.b6c374d66d57.png" alt="Mereka Academy - Studio" />
        </a>
      </h1>
    </div>
    <div class="wrapper wrapper-r">
      <nav class="nav-not-signedin nav-pitch" aria-label="Account">
        <h2 class="sr-only">Account Navigation</h2>
        <ol>
          <li class="nav-item nav-not-signedin-help">
            <a href="https://edx.readthedocs.io/projects/open-edx-building-and-running-a-course/en/open-release-redwood.master/index.html" title="Contextual Online Help" rel="noopener" target="_blank">Help</a>
          </li>
              <li class="nav-item nav-not-signedin-signup">
                <a class="action action-signup" href="https://academyv2.mereka.dev/register?next=http%3A%2F%2Fstudio.academyv2.mereka.dev%2Flogin%2F">Sign Up</a>
              </li>
          <li class="nav-item nav-not-signedin-signin">
            <a class="action action-signin" href="/login/?next=http%3A%2F%2Fstudio.academyv2.mereka.dev%2Fmetrics">Sign In</a>
          </li>
        </ol>
      </nav>
    </div>
  </header>
</div>
      <div id="page-alert">
      </div>
      <main id="main" aria-label="Content" tabindex="-1">
        <div id="content">
<div class="wrapper-content wrapper">
  <section class="content">
    <header>
      <h1 class="title title-1">Page not found</h1>
    </header>
    <article class="content-primary" role="main">
      <p>
      The page that you were looking for was not found.
      Go back to the <a href="/">homepage</a>.
      </p>
    </article>
  </section>
</div>
        </div>
      </main>
<div class="wrapper-footer wrapper">
  <footer class="primary" role="contentinfo">
    <div class="footer-content-primary">
      <div class="colophon">
        <p>&copy; 2026 <a href="#" rel="external">Mereka Academy Studio</a>.</p>
      </div>
        <nav class="nav-peripheral" aria-label="Policies">
          <ol>
            <li class="nav-item">
              <a id="lms-link" href="https://academyv2.mereka.dev">LMS</a>
            </li>
          </ol>
        </nav>
    </div>
    <div class="footer-content-secondary" aria-label="Legal">
      <div class="footer-about-copyright">
        <p>
          edX, Open edX, and the edX and Open edX logos are registered trademarks of <a href='https://www.edx.org/'>edX Inc.</a>
        </p>
      </div>
      <div class="footer-about-openedx">
        <a href="https://open.edx.org" title="Powered by Open edX">
          <img alt="Powered by Open edX" src="https://logos.openedx.org/open-edx-logo-tag.png">
        </a>
      </div>
    </div>
  </footer>
</div>
      <div id="page-notification"></div>
    </div>
    <div id="page-prompt"></div>
      <script type="text/javascript">
      require(['js/factories/base'], function () {
      });
      </script>
    <div class="modal-cover"></div>
  </body>
  <script>
	var beamer_config = {
		product_id : ""
	};
    </script>
<script type="text/javascript" src="https://app.getbeamer.com/js/beamer-embed.js" defer="defer"></script>
</html>
```
