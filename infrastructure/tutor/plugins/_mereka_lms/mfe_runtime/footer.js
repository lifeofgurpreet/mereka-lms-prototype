// Footer component and related helpers.
// MerekaFooter is wired into org.openedx.frontend.layout.footer.v1 by PLUGIN_SLOTS in mereka_lms.py.

const getMerekaFooterNavLinks = (footerContent, footerSupport, variant) => {
  const configuredLinks = Array.isArray(footerContent.navLinks) ? footerContent.navLinks : [];
  return [
    ...configuredLinks,
    { label: footerSupport.helpLabel || 'Help Centre', url: variant.helpUrl },
    { label: footerSupport.contactSupportLabel || 'Contact Support', url: 'mailto:' + variant.supportEmail },
  ];
};

// Custom Mereka footer component (Direct plugin — registered via footer_slot)
// Wired into org.openedx.frontend.layout.footer.v1 by PLUGIN_SLOTS in mereka_lms.py
const MerekaFooter = () => {
  const config = getConfig();
  const baseUrl = getMerekaBaseUrl(config);
  const currentYear = new Date().getFullYear();
  const hostname = typeof window !== 'undefined' ? window.location.hostname : '';
  const variant = getMerekaVariant(hostname, config);
  const footerContent = getMerekaPublicFooter(config);
  const footerSupport = footerContent.support || {};
  const footerSections = footerContent.sections || {};
  const footerMarketplace = footerSections.marketplace || {};
  const footerLegal = footerContent.legal || {};
  const logoPath = variant.logoUrl || '/theme/logo-horizontal.svg';
  const logoUrl = getMerekaThemeAssetUrl(config, logoPath);
  const socialLinks = footerContent.socialLinks;
  const footerNavLinks = getMerekaFooterNavLinks(footerContent, footerSupport, variant);
  const corporateLinks = (footerSections.corporate && footerSections.corporate.links) || [];
  const marketplaceUserLinks = footerMarketplace.userLinks || [];
  const marketplaceBusinessLinks = footerMarketplace.businessLinks || [];
  const academyLinks = (footerSections.academy && footerSections.academy.links) || [];
  const spaceLinks = (footerSections.space && footerSections.space.links) || [];

  const SocialIcon = ({ d }) => (
    <svg
      className="mereka-footer__social-icon"
      style={socialIconStyle}
      fill="currentColor"
      viewBox="0 0 24 24"
    >
      <path d={d} />
    </svg>
  );

  const WhatsAppIcon = () => (
    <svg
      className="mereka-footer__social-icon"
      style={whatsappIconStyle}
      fill="currentColor"
      viewBox="0 0 24 24"
    >
      <path d="M.057 24l1.687-6.163c-1.041-1.804-1.588-3.849-1.587-5.946.003-6.556 5.338-11.891 11.893-11.891 3.181.001 6.167 1.24 8.413 3.488 2.245 2.248 3.481 5.236 3.48 8.414-.003 6.557-5.338 11.892-11.893 11.892-1.99-.001-3.951-.5-5.688-1.448l-6.305 1.654zm6.597-3.807c1.676.995 3.276 1.591 5.392 1.592 5.448 0 9.886-4.434 9.889-9.885.002-5.462-4.415-9.89-9.881-9.892-5.452 0-9.887 4.434-9.889 9.884-.001 2.225.651 3.891 1.746 5.634l-.999 3.648 3.742-.981zm11.387-5.464c-.074-.124-.272-.198-.57-.347-.297-.149-1.758-.868-2.031-.967-.272-.099-.47-.149-.669.149-.198.297-.768.967-.941 1.165-.173.198-.347.223-.644.074-.297-.149-1.255-.462-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.297-.347.446-.521.151-.172.2-.296.3-.495.099-.198.05-.372-.025-.521-.075-.148-.669-1.611-.916-2.206-.242-.579-.487-.501-.669-.51l-.57-.01c-.198 0-.52.074-.792.372s-1.04 1.016-1.04 2.479 1.065 2.876 1.213 3.074c.149.198 2.095 3.2 5.076 4.487.709.306 1.263.489 1.694.626.712.226 1.36.194 1.872.118.571-.085 1.758-.719 2.006-1.413.248-.695.248-1.29.173-1.414z" />
    </svg>
  );

  const socialIconStyle = {
    width: '20px',
    height: '20px',
  };

  const whatsappIconStyle = {
    width: '20px',
    height: '20px',
    color: '#25D366',
  };

  return (
    <footer className="mereka-footer mereka-footer--v2" role="contentinfo">
      {/* Zone 1: Social Row */}
      <div className="footer-social">
        <div className="footer-container">
          <a href={baseUrl || '/'} className="footer-logo-link">
            {logoUrl ? <img src={logoUrl} alt={variant.brand + ' logo'} className="footer-logo-img" /> : null}
            <span className="footer-brand-name">{(footerContent.brand && footerContent.brand.logoText) || 'mereka'}</span>
          </a>
          <div className="footer-social-icons">
            {socialLinks.map(s => (
              <a key={s.name} href={s.url} target="_blank" rel="noopener noreferrer" aria-label={s.name} className="footer-social-link">
                <SocialIcon d={s.iconPath} />
              </a>
            ))}
          </div>
        </div>
      </div>

      {/* Zone 2: Nav Strip */}
      <div className="footer-nav">
        <div className="footer-container">
          <nav className="footer-nav-links">
            {footerNavLinks.map(l => (
              <a key={l.label} href={l.url} target="_blank" rel="noopener noreferrer">{l.label}</a>
            ))}
          </nav>
          <a href={'https://wa.me/' + (variant.whatsapp || footerSupport.whatsapp || '601135271981')} target="_blank" rel="noopener noreferrer" className="footer-whatsapp-btn">
            <WhatsAppIcon /> {footerSupport.contactCtaLabel || 'Contact Us'}
          </a>
        </div>
      </div>

      {/* Zone 3: 4-Column Body */}
      <div className="footer-body">
        <div className="footer-container footer-columns">
          <div className="footer-column">
            <h4 className="footer-column-title">{(footerSections.corporate && footerSections.corporate.title) || 'Corporate'}</h4>
            <ul>{corporateLinks.map(l => <li key={l.label}><a href={l.url} target="_blank" rel="noopener noreferrer">{l.label}</a></li>)}</ul>
          </div>
          <div className="footer-column footer-column--wide">
            <h4 className="footer-column-title">{footerMarketplace.title || 'Marketplace'}</h4>
            <div className="footer-marketplace-grid">
              <div>
                <p className="footer-sub-heading">{footerMarketplace.usersHeading || 'USERS'}</p>
                <ul>{marketplaceUserLinks.map(l => <li key={l.label}><a href={l.url} target="_blank" rel="noopener noreferrer">{l.label}</a></li>)}</ul>
              </div>
              <div>
                <p className="footer-sub-heading">{footerMarketplace.businessHeading || 'BUSINESS'}</p>
                <ul>{marketplaceBusinessLinks.map(l => <li key={l.label}><a href={l.url} target="_blank" rel="noopener noreferrer">{l.label}</a></li>)}</ul>
                <p className="footer-app-label">{footerMarketplace.appLabel || 'Manage your bookings'}</p>
                <div className="footer-app-badges">
                  {(footerMarketplace.appBadges || []).map(badge => (
                    <a key={badge.label} href={badge.url} target="_blank" rel="noopener noreferrer" className="footer-badge">{badge.label}</a>
                  ))}
                </div>
                <a href={(footerMarketplace.cta && footerMarketplace.cta.url) || 'https://mereka.io/welcome/hub'} target="_blank" rel="noopener noreferrer" className="footer-cta-btn">{(footerMarketplace.cta && footerMarketplace.cta.label) || 'Become a Hub'}</a>
              </div>
            </div>
          </div>
          <div className="footer-column">
            <h4 className="footer-column-title">{(footerSections.academy && footerSections.academy.title) || 'Academy'}</h4>
            <ul>{academyLinks.map(l => <li key={l.label}><a href={l.url} target="_blank" rel="noopener noreferrer">{l.label}</a></li>)}</ul>
          </div>
          <div className="footer-column">
            <h4 className="footer-column-title">{(footerSections.space && footerSections.space.title) || 'Space'}</h4>
            <ul>{spaceLinks.map(l => <li key={l.label}><a href={l.url} target="_blank" rel="noopener noreferrer">{l.label}</a></li>)}</ul>
          </div>
        </div>
      </div>

      {/* Zone 4: Legal Bottom — URLs resolved from tenant data contract (variant) */}
      <div className="footer-legal">
        <div className="footer-container footer-legal-row">
          <span className="footer-copyright">&copy; {currentYear} {variant.copyrightHolder}</span>
          <a href={variant.termsUrl} target="_blank" rel="noopener noreferrer">{footerLegal.termsLabel || 'TERMS OF USE'}</a>
          <a href={variant.privacyUrl} target="_blank" rel="noopener noreferrer">{footerLegal.privacyLabel || 'PRIVACY POLICY'}</a>
          <a href={variant.cookiesUrl} target="_blank" rel="noopener noreferrer">{footerLegal.cookiesLabel || 'COOKIES POLICY'}</a>
        </div>
      </div>
    </footer>
  );
};
