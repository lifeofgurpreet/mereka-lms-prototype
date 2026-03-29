// Certificate, profile, and account verification components.
// Includes MerekaProgressCertificateStatus, MerekaAdditionalProfileFields, and ID verification hint.

const getCertificateReadinessSteps = (variantBrand) => ([
  {
    label: '01',
    title: 'Finish the learning plan',
    body: `Complete the remaining units, graded work, and required activities so ${variantBrand} can issue a complete completion record.`,
  },
  {
    label: '02',
    title: 'Confirm profile details',
    body: 'Keep your profile name, organization context, and supporting details current so certificate records stay accurate.',
  },
  {
    label: '03',
    title: 'Clear identity checks if required',
    body: 'Some programs require ID review before release. Treat it as the final gate, not a surprise after you finish the course.',
  },
]);

const MerekaCertificateReadinessSteps = ({ steps }) => (
  <ol className="mereka-certificate-readiness__steps list-unstyled mb-0">
    {steps.map((step) => (
      <li key={step.label} className="mereka-certificate-readiness__step">
        <span className="mereka-certificate-readiness__step-index" aria-hidden="true">{step.label}</span>
        <div className="mereka-certificate-readiness__step-copy">
          <p className="mereka-certificate-readiness__step-title mb-1">{step.title}</p>
          <p className="mereka-certificate-readiness__step-body mb-0">{step.body}</p>
        </div>
      </li>
    ))}
  </ol>
);

const MerekaCertificateContextMetaItem = ({ label, value }) => (
  <li className="mereka-additional-profile-fields__item">
    <span className="mereka-additional-profile-fields__label">{label}</span>
    <strong className="mereka-additional-profile-fields__value">{value}</strong>
  </li>
);

const MerekaCertificateContextShell = ({
  className,
  eyebrow,
  title,
  titleClassName = 'mereka-progress-certificate-status__title mb-1',
  body,
  bodyClassName = 'mereka-progress-certificate-status__body mb-0',
  status,
  steps,
  meta,
  hint,
  hintClassName = 'mereka-progress-certificate-status__hint mb-0',
}) => (
  <section className={className}>
    <div className="mereka-shell-panel__content">
      <div className="mereka-progress-certificate-status__header">
        <div>
          <p className="mereka-shell-kicker mb-2">{eyebrow}</p>
          <p className={titleClassName}>{title}</p>
        </div>
        {status ? <span className="mereka-progress-certificate-status__status">{status}</span> : null}
      </div>
      {body ? <p className={bodyClassName}>{body}</p> : null}
      {steps}
      {meta}
      {hint ? <p className={hintClassName}>{hint}</p> : null}
    </div>
  </section>
);

// Learning progress certificate status branding and context card.
// Wired into org.openedx.frontend.learning.progress_certificate_status.v1.
const MerekaProgressCertificateStatus = ({ courseId }) => {
  const config = getConfig();
  const variant = getMerekaVariant(typeof window !== 'undefined' ? window.location.hostname : '', config);
  const safeCourseId = typeof courseId === 'string' ? courseId : '';
  const steps = getCertificateReadinessSteps(variant.brand);

  return (
    <MerekaCertificateContextShell
      className="mereka-progress-certificate-status mereka-shell-panel my-3"
      eyebrow="Certificate readiness"
      title="Keep your certificate within reach"
      body={`${variant.brand} Learning${safeCourseId ? ` course ${safeCourseId}` : ''} is active. Use the checklist below to move from course progress to certificate release without guesswork.`}
      status="In progress"
      steps={<MerekaCertificateReadinessSteps steps={steps} />}
      hint="Completion unlocks the certificate, but clean profile and verification data keep the release path fast and predictable."
    />
  );
};

// Account ID verification helper slot.
// Wired into org.openedx.frontend.account.id_verification_page.v1.
const MerekaAccountIdVerificationHint = () => {
  return (
    <MerekaCertificateContextShell
      className="mereka-account-id-verification-hint mereka-shell-panel mb-3"
      eyebrow="Identity review"
      title="Identity review protects certificate trust"
      titleClassName="mereka-account-id-verification-hint__title mb-1"
      body="ID verification details are reviewed by your learning administrator for secure certificate issuance. Finish this step before course completion so certificate release does not stall at the last mile."
      bodyClassName="mereka-account-id-verification-hint__body mb-0"
    />
  );
};

// Enterprise profile section for account/profile additional profile field slots.
// Wired into org.openedx.frontend.account.additional_profile_fields.v1 and
// org.openedx.frontend.profile.additional_profile_fields.v1.
const MerekaAdditionalProfileFields = () => {
  const config = getConfig();
  const variant = getMerekaVariant(typeof window !== 'undefined' ? window.location.hostname : '', config);
  const profileMeta = (
    <ul className="mereka-additional-profile-fields__list list-unstyled mb-0">
      <MerekaCertificateContextMetaItem label="Organization" value={variant.brand} />
      <MerekaCertificateContextMetaItem label="Job title" value="Required before certificate export" />
      <MerekaCertificateContextMetaItem label="Department" value="Used for enterprise reporting" />
    </ul>
  );

  return (
    <MerekaCertificateContextShell
      className="mereka-additional-profile-fields mereka-shell-panel mb-3"
      eyebrow="Certificate readiness"
      title="Finish the profile details certificates depend on"
      titleClassName="mereka-additional-profile-fields__title h5 mb-2"
      body={`For ${variant.brand} workplace setups, these fields anchor certificate identity, reporting, and downstream enterprise records. Keep them aligned before you request a certificate.`}
      bodyClassName="mereka-additional-profile-fields__body mb-3"
      meta={profileMeta}
      hint="Match these details to the learner name and ID context you expect to appear alongside your certificate record."
      hintClassName="mereka-additional-profile-fields__hint mb-0"
    />
  );
};
