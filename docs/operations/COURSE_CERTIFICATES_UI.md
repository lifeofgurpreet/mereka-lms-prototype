# Course Certificates: Where To Check Issues (UI)
_Audience: Course staff (instructors, course team) • Owner: Platform Eng_

This doc is about **learner course completion certificates** (not TLS/SSL certs).

## Instructor View (Recommended)

1. Go to the course in the LMS.
2. Open **Instructor** (Instructor Dashboard) from the course navigation.
3. Open the **Certificates** section/tab.

In the Instructor Dashboard you can:

- Confirm certificates are enabled for the course.
- Trigger certificate generation for learners.
- See certificate status and common error reasons (when available).

## Learner View (What Learners See)

- Learners usually access certificates from the LMS **Dashboard** via **View Certificate** on a completed course card.
- Depending on configuration, learners may also have a **My Certificates** page linked from the account menu.

## Studio (Authoring / Configuration)

Certificates can also be configured from Studio for a course:

1. Open the course in Studio.
2. Go to the course settings area (Certificates settings, if enabled in this release).

## If Studio/LMS Login Is Broken

Run the auth gates first:

```bash
./scripts/qa/verify-auth-surfaces.sh prod
RUN_AUTHENTICATED_SSO_CANARY=1 AUTHENTICATED_SSO_CANARY_REQUIRE_SECRETS=1 \
  ./scripts/qa/verify-authenticated-sso-canary.sh --env prod
```

If these fail, treat it as release-blocking and fix SSO before debugging certificate UI.

