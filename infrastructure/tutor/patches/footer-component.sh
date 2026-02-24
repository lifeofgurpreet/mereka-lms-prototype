#!/usr/bin/env bash
# Patch: Custom Mereka footer component for MFEs.
# Injects MerekaFooter React component into env.config.jsx and wires it
# into the plugin slot system. Also handles SCSS import and theme copy for MFE build.

apply_footer_component_patch() {
  local targets=(
    "$MFE_INDIGO_ENV_TEMPLATE"
    "$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/indigo/env.config.jsx"
  )

  python - "${targets[@]}" <<'FOOTERPY'
from pathlib import Path
import textwrap
import sys

targets = sys.argv[1:]

for target in targets:
    path = Path(target)
    if not path.exists():
        continue
    if path.name != "env.config.jsx":
        continue
    original = path.read_text()
    updated = original

    # Remove stock Indigo footer import
    updated = updated.replace("import Footer from '@edly-io/indigo-frontend-component-footer';\n", "")

    # Inject mereka.scss import
    css_hook = "import { DIRECT_PLUGIN, PLUGIN_OPERATIONS } from '@openedx/frontend-plugin-framework';\n"
    css_target = css_hook + "import './mereka/mereka.scss';\n"
    if "mereka/mereka.scss" not in updated:
        if css_hook in updated:
            updated = updated.replace(css_hook, css_target)
        else:
            get_config_import = "import { getConfig } from '@edx/frontend-platform';\n"
            if get_config_import in updated:
                updated = updated.replace(get_config_import, get_config_import + "import './mereka/mereka.scss';\n", 1)

    # MerekaFooter component definition
    footer_component = textwrap.dedent(
        r"""
        const MerekaFooter = () => {
          const config = getConfig();
          const baseUrl = (config.LMS_BASE_URL || '').replace(/\/$/, '');
          const siteName = config.SITE_NAME || 'Mereka Academy';
          const currentYear = new Date().getFullYear();
          const hostname = typeof window !== 'undefined' ? window.location.hostname : '';
          const logoUrl = baseUrl ? baseUrl + '/static/images/logo.png' : '';

          const SITE_VARIANTS = {
            'academyv2.mereka.io': { brand: 'Mereka Academy', copyrightHolder: 'MEREKA', whatsapp: '601135271981' },
            'academy.biji-biji.com': { brand: 'Biji-Biji Academy', copyrightHolder: 'Biji-Biji Initiative', whatsapp: '601135271981' },
            'skillourfuture.academy.mereka.io': { brand: 'Skill Our Future Academy', copyrightHolder: 'MEREKA', whatsapp: '601135271981' },
          };
          const variant = SITE_VARIANTS[hostname] || { brand: siteName, copyrightHolder: 'MEREKA', whatsapp: '601135271981' };

          const socialLinks = [
            { name: 'TikTok', url: 'https://www.tiktok.com/@mereka.io', icon: 'M19.59 6.69a4.83 4.83 0 0 1-3.77-4.25V2h-3.45v13.67a2.89 2.89 0 0 1-5.2 1.74 2.89 2.89 0 0 1 2.31-4.64 2.93 2.93 0 0 1 .88.13V9.4a6.84 6.84 0 0 0-1-.05A6.33 6.33 0 0 0 5 20.1a6.34 6.34 0 0 0 10.86-4.43v-7a8.16 8.16 0 0 0 4.77 1.52v-3.4a4.85 4.85 0 0 1-1-.1z' },
            { name: 'Instagram', url: 'https://www.instagram.com/mereka.io/', icon: 'M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zm0-2.163c-3.259 0-3.667.014-4.947.072-4.358.2-6.78 2.618-6.98 6.98-.059 1.281-.073 1.689-.073 4.948 0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98-1.281-.059-1.69-.073-4.949-.073zm0 5.838c-3.403 0-6.162 2.759-6.162 6.162s2.759 6.163 6.162 6.163 6.162-2.759 6.162-6.163c0-3.403-2.759-6.162-6.162-6.162zm0 10.162c-2.209 0-4-1.79-4-4 0-2.209 1.791-4 4-4s4 1.791 4 4c0 2.21-1.791 4-4 4zm6.406-11.845c-.796 0-1.441.645-1.441 1.44s.645 1.44 1.441 1.44c.795 0 1.439-.645 1.439-1.44s-.644-1.44-1.439-1.44z' },
            { name: 'Facebook', url: 'https://www.facebook.com/mereka.io', icon: 'M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z' },
            { name: 'LinkedIn', url: 'https://www.linkedin.com/company/mereka/', icon: 'M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z' },
            { name: 'YouTube', url: 'https://www.youtube.com/channel/UCCyMH5KIZeCMchjMKl7RWxg', icon: 'M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z' },
          ];

          const navLinks = [
            { label: 'About', url: 'https://corporate.mereka.io/about-us' },
            { label: 'Andragogy', url: 'https://corporate.mereka.io/andragogy' },
            { label: 'Portfolio', url: 'https://corporate.mereka.io/portfolio' },
            { label: 'Team', url: 'https://corporate.mereka.io/our-team' },
            { label: 'Careers', url: 'https://corporate.mereka.io/work-with-us' },
            { label: 'Ecosystem', url: 'https://corporate.mereka.io/ecosystem' },
            { label: 'Blog', url: 'https://corporate.mereka.io/blog' },
            { label: 'Help Centre', url: 'https://help.mereka.io/' },
          ];

          const corporateLinks = [
            { label: 'Accelerate Talent', url: 'https://corporate.mereka.io/academy/funders' },
            { label: 'Create Online Course', url: 'https://corporate.mereka.io/academy/create-online-courses' },
            { label: 'Build a Makerspace', url: 'https://corporate.mereka.io/academy/makerspace' },
          ];

          const marketplaceUserLinks = [
            { label: 'Experiences', url: 'https://mereka.io/experiences' },
            { label: 'Experts', url: 'https://mereka.io/experts' },
            { label: 'Expertise', url: 'https://mereka.io/expertise' },
            { label: 'Hubs', url: 'https://mereka.io/hubs' },
            { label: 'Spaces', url: 'https://corporate.mereka.io/space' },
          ];

          const marketplaceBusinessLinks = [
            { label: 'Pricing', url: 'https://hubs.mereka.io/pricing' },
            { label: 'Solutions', url: 'https://hubs.mereka.io/howitworks' },
          ];

          const academyLinks = [
            { label: 'Future of Work', url: 'https://corporate.mereka.io/academy/future-of-work' },
            { label: 'Digital Entrepreneur', url: 'https://corporate.mereka.io/academy/digital-entrepreneur' },
            { label: 'All Courses', url: 'https://corporate.mereka.io/academy/all-courses' },
          ];

          const spaceLinks = [
            { label: 'Mereka @ Publika', url: 'https://corporate.mereka.io/publika' },
            { label: 'Our Labs', url: 'https://corporate.mereka.io/space#labs' },
            { label: 'Bespoke Design', url: 'https://corporate.mereka.io/space/innovate#products' },
            { label: 'Host Events', url: 'https://corporate.mereka.io/space#event-cta' },
          ];

          const SocialIcon = ({ d }) => (
            <svg style={{ width: '20px', height: '20px' }} fill="currentColor" viewBox="0 0 24 24"><path d={d} /></svg>
          );

          const WhatsAppIcon = () => (
            <svg style={{ width: '20px', height: '20px', color: '#25D366' }} fill="currentColor" viewBox="0 0 24 24">
              <path d="M.057 24l1.687-6.163c-1.041-1.804-1.588-3.849-1.587-5.946.003-6.556 5.338-11.891 11.893-11.891 3.181.001 6.167 1.24 8.413 3.488 2.245 2.248 3.481 5.236 3.48 8.414-.003 6.557-5.338 11.892-11.893 11.892-1.99-.001-3.951-.5-5.688-1.448l-6.305 1.654zm6.597-3.807c1.676.995 3.276 1.591 5.392 1.592 5.448 0 9.886-4.434 9.889-9.885.002-5.462-4.415-9.89-9.881-9.892-5.452 0-9.887 4.434-9.889 9.884-.001 2.225.651 3.891 1.746 5.634l-.999 3.648 3.742-.981zm11.387-5.464c-.074-.124-.272-.198-.57-.347-.297-.149-1.758-.868-2.031-.967-.272-.099-.47-.149-.669.149-.198.297-.768.967-.941 1.165-.173.198-.347.223-.644.074-.297-.149-1.255-.462-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.297-.347.446-.521.151-.172.2-.296.3-.495.099-.198.05-.372-.025-.521-.075-.148-.669-1.611-.916-2.206-.242-.579-.487-.501-.669-.51l-.57-.01c-.198 0-.52.074-.792.372s-1.04 1.016-1.04 2.479 1.065 2.876 1.213 3.074c.149.198 2.095 3.2 5.076 4.487.709.306 1.263.489 1.694.626.712.226 1.36.194 1.872.118.571-.085 1.758-.719 2.006-1.413.248-.695.248-1.29.173-1.414z" />
            </svg>
          );

          return (
            <footer className="mereka-footer mereka-footer--v2" role="contentinfo">
              {/* Zone 1: Social Row */}
              <div className="footer-social">
                <div className="footer-container">
                  <a href={baseUrl || '/'} className="footer-logo-link">
                    {logoUrl ? <img src={logoUrl} alt={variant.brand + ' logo'} className="footer-logo-img" /> : null}
                    <span className="footer-brand-name">mereka</span>
                  </a>
                  <div className="footer-social-icons">
                    {socialLinks.map(s => (
                      <a key={s.name} href={s.url} target="_blank" rel="noopener noreferrer" aria-label={s.name} className="footer-social-link">
                        <SocialIcon d={s.icon} />
                      </a>
                    ))}
                  </div>
                </div>
              </div>

              {/* Zone 2: Nav Strip */}
              <div className="footer-nav">
                <div className="footer-container">
                  <nav className="footer-nav-links">
                    {navLinks.map(l => (
                      <a key={l.label} href={l.url} target="_blank" rel="noopener noreferrer">{l.label}</a>
                    ))}
                  </nav>
                  <a href={'https://wa.me/' + variant.whatsapp} target="_blank" rel="noopener noreferrer" className="footer-whatsapp-btn">
                    <WhatsAppIcon /> Contact Us
                  </a>
                </div>
              </div>

              {/* Zone 3: 4-Column Body */}
              <div className="footer-body">
                <div className="footer-container footer-columns">
                  <div className="footer-column">
                    <h4 className="footer-column-title">Corporate</h4>
                    <ul>{corporateLinks.map(l => <li key={l.label}><a href={l.url} target="_blank" rel="noopener noreferrer">{l.label}</a></li>)}</ul>
                  </div>
                  <div className="footer-column footer-column--wide">
                    <h4 className="footer-column-title">Marketplace</h4>
                    <div className="footer-marketplace-grid">
                      <div>
                        <p className="footer-sub-heading">USERS</p>
                        <ul>{marketplaceUserLinks.map(l => <li key={l.label}><a href={l.url} target="_blank" rel="noopener noreferrer">{l.label}</a></li>)}</ul>
                      </div>
                      <div>
                        <p className="footer-sub-heading">BUSINESS</p>
                        <ul>{marketplaceBusinessLinks.map(l => <li key={l.label}><a href={l.url} target="_blank" rel="noopener noreferrer">{l.label}</a></li>)}</ul>
                        <p className="footer-app-label">Manage your bookings</p>
                        <div className="footer-app-badges">
                          <a href="https://apps.apple.com/id/app/mereka-hubs/id6473277964" target="_blank" rel="noopener noreferrer" className="footer-badge">App Store</a>
                          <a href="https://play.google.com/store/apps/details?id=io.mereka.hubs" target="_blank" rel="noopener noreferrer" className="footer-badge">Google Play</a>
                        </div>
                        <a href="https://mereka.io/welcome/hub" target="_blank" rel="noopener noreferrer" className="footer-cta-btn">Become a Hub</a>
                      </div>
                    </div>
                  </div>
                  <div className="footer-column">
                    <h4 className="footer-column-title">Academy</h4>
                    <ul>{academyLinks.map(l => <li key={l.label}><a href={l.url} target="_blank" rel="noopener noreferrer">{l.label}</a></li>)}</ul>
                  </div>
                  <div className="footer-column">
                    <h4 className="footer-column-title">Space</h4>
                    <ul>{spaceLinks.map(l => <li key={l.label}><a href={l.url} target="_blank" rel="noopener noreferrer">{l.label}</a></li>)}</ul>
                  </div>
                </div>
              </div>

              {/* Zone 4: Legal Bottom */}
              <div className="footer-legal">
                <div className="footer-container footer-legal-row">
                  <span className="footer-copyright">&copy; {currentYear} {variant.copyrightHolder}</span>
                  <a href="https://legal.mereka.io/" target="_blank" rel="noopener noreferrer">TERMS OF USE</a>
                  <a href="https://legal.mereka.io/privacy-policy/" target="_blank" rel="noopener noreferrer">PRIVACY POLICY</a>
                  <a href="https://legal.mereka.io/#cookie-policy" target="_blank" rel="noopener noreferrer">COOKIES POLICY</a>
                </div>
              </div>
            </footer>
          );
        };
        """
    ).strip()

    if "const MerekaFooter" not in updated:
        updated = updated.replace("const themePluginSlot =", footer_component + "\n\nconst themePluginSlot =", 1)

    # MIGRATED-TO-SLOT: footer_slot
    if "RenderWidget: <MerekaFooter />" not in updated and "const MerekaFooter" in updated:
        updated = updated.replace(
            "RenderWidget: IndigoFooter,",
            "RenderWidget: <MerekaFooter />,  // MIGRATED-TO-SLOT: footer_slot (fallback)",
            1,
        )

    if updated != original:
        path.write_text(updated)
FOOTERPY

  # Copy MFE theme SCSS/fonts into indigo build directory
  local MFE_INDIGO_DIR="$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/indigo"
  if [ -d "$MFE_INDIGO_DIR" ]; then
    mkdir -p "$MFE_INDIGO_DIR/mereka"
    rm -rf "$MFE_INDIGO_DIR/mereka/scss"
    cp -R "$REPO_ROOT/infrastructure/tutor/themes/mereka/scss" "$MFE_INDIGO_DIR/mereka/scss"
    rm -rf "$MFE_INDIGO_DIR/mereka/fonts"
    cp -R "$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/fonts" "$MFE_INDIGO_DIR/mereka/fonts"
    cp "$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/mereka.scss" "$MFE_INDIGO_DIR/mereka/mereka.scss"
  fi

  # Ensure top-level MFE env.config.jsx imports our theme
  local MFE_ENV_CONFIG="$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/env.config.jsx"
  if [ -f "$MFE_ENV_CONFIG" ] && ! grep -q "mereka/mereka.scss" "$MFE_ENV_CONFIG"; then
    python - "$MFE_ENV_CONFIG" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8", errors="ignore")
if "mereka/mereka.scss" in text:
    raise SystemExit(0)

needle = "import { getConfig } from '@edx/frontend-platform';\n"
insertion = needle + "import './mereka/mereka.scss';\n"
if needle in text:
    text = text.replace(needle, insertion, 1)
else:
    lines = text.splitlines(True)
    out = []
    inserted = False
    for line in lines:
        out.append(line)
        if not inserted and line.startswith("import ") and line.rstrip().endswith(";"):
            continue
        if not inserted and not line.startswith("import "):
            out.insert(len(out) - 1, "import './mereka/mereka.scss';\n")
            inserted = True
    text = "".join(out)

path.write_text(text, encoding="utf-8")
PY
  fi

  # Normalize any historical duplicate inserts
  if [ -f "$MFE_ENV_CONFIG" ]; then
    python - "$MFE_ENV_CONFIG" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

path = Path(sys.argv[1])
lines = path.read_text(encoding="utf-8", errors="ignore").splitlines(True)
import_line = "import './mereka/mereka.scss';\n"
cleaned = [ln for ln in lines if ln != import_line]

needle = "import { getConfig } from '@edx/frontend-platform';\n"
out = []
inserted = False
for ln in cleaned:
    out.append(ln)
    if not inserted and ln == needle:
        out.append(import_line)
        inserted = True

if not inserted:
    out2 = []
    last_import_idx = -1
    for idx, ln in enumerate(out):
        out2.append(ln)
        if ln.startswith("import "):
            last_import_idx = idx
    if last_import_idx >= 0:
        out2.insert(last_import_idx + 1, import_line)
        out = out2
    else:
        out.insert(0, import_line)

path.write_text("".join(out), encoding="utf-8")
PY
  fi
}
