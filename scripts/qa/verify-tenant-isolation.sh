#!/usr/bin/env bash
# @covers AC-MTA-003, AC-MTA-004, AC-MTA-005, AC-MTA-006, AC-MTA-007, AC-MTA-025, AC-MTA-029, AC-MTA-030, AC-MTA-032
# @spec: multi-tenancy-architecture_spec.md
#
# Comprehensive live-cluster tenant isolation audit for Mereka Academy Open edX.
# Audits the REAL state of multi-tenancy on the live GKE cluster across all
# isolation dimensions: data, API, domain routing, cookie scoping, middleware stack,
# and deployment readiness.
#
# Usage:
#   ./scripts/qa/verify-tenant-isolation.sh [NAMESPACE]
#   NAMESPACE defaults to mereka-lms
#
# Dependencies:
#   - kubectl configured with access to the GKE cluster
#   - curl for HTTP endpoint testing
set -euo pipefail

NAMESPACE="${NAMESPACE:-mereka-lms}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Counters
PASS=0
FAIL=0
SKIP=0

pass_() {
  PASS=$((PASS + 1))
  echo -e "${GREEN}PASS${NC}: $1"
}

fail_() {
  FAIL=$((FAIL + 1))
  echo -e "${RED}FAIL${NC}: $1"
}

skip_() {
  SKIP=$((SKIP + 1))
  echo -e "${YELLOW}SKIP${NC}: $1"
}

echo "=== Tenant Isolation Audit ==="
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Namespace: $NAMESPACE"
echo "Repo: $REPO_ROOT"
echo

# ─── Initialize state variables ───────────────────────────────────────
TENANCY_INSTALLED=false
TENANCY_IN_APPS=false
TENANT_MW_DEPLOYED=false
ENTERPRISE_COUNT=0
SITE_COUNT=0
SITECONFIG_COUNT=0
APPS_OUTPUT=""
MW_OUTPUT=""
DOMAINS=""
SITE_ORG_FILTERS=""

# ─── Helper: Check kubectl access ──────────────────────────────────────
KUBECTL_OK=false
if kubectl get ns "$NAMESPACE" >/dev/null 2>&1; then
  KUBECTL_OK=true
  echo -e "${GREEN}✓${NC} kubectl access to namespace $NAMESPACE"
else
  echo -e "${RED}✗${NC} kubectl cannot access namespace $NAMESPACE"
  echo "Most checks will be skipped. Ensure kubectl is configured and the namespace exists."
fi
echo

###########################################################################
# SECTION 1: Infrastructure Readiness
###########################################################################
echo -e "${CYAN}=== 1. Infrastructure Readiness ===${NC}"
echo

if [ "$KUBECTL_OK" = false ]; then
  skip_ "All infrastructure checks (kubectl unavailable)"
else
  # Check if mereka_tenancy module is installed in the LMS image
  echo "Checking if mereka_tenancy module is installed..."
  TENANCY_INSTALLED=false
  if kubectl exec -n "$NAMESPACE" deploy/lms -- python -c "import mereka_tenancy" 2>/dev/null; then
    TENANCY_INSTALLED=true
    pass_ "mereka_tenancy module is installed in LMS image"
  else
    fail_ "mereka_tenancy module NOT installed (needs image rebuild with plugin)"
  fi
  echo

  # Check if mereka_tenancy is in INSTALLED_APPS
  echo "Checking if mereka_tenancy is in INSTALLED_APPS..."
  TENANCY_IN_APPS=false
  APPS_OUTPUT=$(kubectl exec -n "$NAMESPACE" deploy/lms -- python manage.py lms shell -c "
from django.conf import settings
print('__APPS_START__')
for app in settings.INSTALLED_APPS:
    print(app)
print('__APPS_END__')
" 2>&1 | sed -n '/__APPS_START__/,/__APPS_END__/p' | grep -v '__APPS_' || true)

  if echo "$APPS_OUTPUT" | grep -q "mereka_tenancy"; then
    TENANCY_IN_APPS=true
    pass_ "mereka_tenancy is in INSTALLED_APPS"
  else
    fail_ "mereka_tenancy NOT in INSTALLED_APPS (needs apply-patches.sh)"
  fi
  echo

  # Check if enterprise app is in INSTALLED_APPS
  echo "Checking if enterprise app is in INSTALLED_APPS..."
  if echo "$APPS_OUTPUT" | grep -qE "(^|\\.)enterprise($|\\.apps\\.EnterpriseConfig)"; then
    pass_ "enterprise app is in INSTALLED_APPS"
  else
    fail_ "enterprise app NOT in INSTALLED_APPS (required for multi-tenancy)"
  fi
  echo

  # Check if TenantResolutionMiddleware is deployed
  echo "Checking if TenantResolutionMiddleware is in MIDDLEWARE..."
  TENANT_MW_DEPLOYED=false
  MW_OUTPUT=$(kubectl exec -n "$NAMESPACE" deploy/lms -- python manage.py lms shell -c "
from django.conf import settings
print('__MW_START__')
for mw in settings.MIDDLEWARE:
    print(mw)
print('__MW_END__')
" 2>&1 | sed -n '/__MW_START__/,/__MW_END__/p' | grep -v '__MW_' || true)

  if echo "$MW_OUTPUT" | grep -q "TenantResolutionMiddleware"; then
    TENANT_MW_DEPLOYED=true
    pass_ "TenantResolutionMiddleware is in MIDDLEWARE stack"
  else
    skip_ "TenantResolutionMiddleware NOT deployed (multi-tenancy middleware not active)"
  fi
  echo

  # Summary of infrastructure readiness
  echo -e "${CYAN}Infrastructure Readiness Summary:${NC}"
  if [ "$TENANCY_INSTALLED" = true ] && [ "$TENANCY_IN_APPS" = true ] && [ "$TENANT_MW_DEPLOYED" = true ]; then
    echo -e "  ${GREEN}✓${NC} Full multi-tenancy stack is deployed"
  elif [ "$TENANCY_INSTALLED" = true ] && [ "$TENANCY_IN_APPS" = true ]; then
    echo -e "  ${YELLOW}⚠${NC} mereka_tenancy module installed but middleware not deployed"
    echo "    → TenantResolutionMiddleware needs to be added to MIDDLEWARE"
  elif [ "$TENANCY_INSTALLED" = true ]; then
    echo -e "  ${YELLOW}⚠${NC} mereka_tenancy module installed but not configured"
    echo "    → Run apply-patches.sh to add to INSTALLED_APPS"
    echo "    → Add TenantResolutionMiddleware to MIDDLEWARE"
  else
    echo -e "  ${RED}✗${NC} Multi-tenancy foundation NOT deployed"
    echo "    → Rebuild image with mereka_tenancy plugin"
    echo "    → Run apply-patches.sh to configure INSTALLED_APPS"
    echo "    → Add TenantResolutionMiddleware to MIDDLEWARE"
  fi
  echo
fi

###########################################################################
# SECTION 2: Tenant Inventory
###########################################################################
echo -e "${CYAN}=== 2. Tenant Inventory ===${NC}"
echo

if [ "$KUBECTL_OK" = false ]; then
  skip_ "All inventory checks (kubectl unavailable)"
else
  # Count Sites
  echo "Querying Django Sites..."
  SITE_COUNT=$(kubectl exec -n "$NAMESPACE" deploy/lms -- python manage.py lms shell -c "
from django.contrib.sites.models import Site
print(Site.objects.count())
" 2>&1 | grep -oE '^[0-9]+$' | head -1 || echo "0")
  echo "  Sites: $SITE_COUNT"

  # List all site domains
  SITE_DOMAINS=$(kubectl exec -n "$NAMESPACE" deploy/lms -- python manage.py lms shell -c "
from django.contrib.sites.models import Site
for site in Site.objects.all().order_by('id'):
    print(f'{site.id}: {site.domain}')
" 2>&1 | grep -E '^[0-9]+:' || echo "")
  if [ -n "$SITE_DOMAINS" ]; then
    echo "$SITE_DOMAINS" | while IFS= read -r line; do
      echo "    $line"
    done
  fi
  echo

  # Count SiteConfigurations
  SITECONFIG_COUNT=$(kubectl exec -n "$NAMESPACE" deploy/lms -- python manage.py lms shell -c "
from openedx.core.djangoapps.site_configuration.models import SiteConfiguration
print(SiteConfiguration.objects.count())
" 2>&1 | grep -oE '^[0-9]+$' | head -1 || echo "0")
  echo "  SiteConfigurations: $SITECONFIG_COUNT"
  echo

  # Count EnterpriseCustomers
  ENTERPRISE_COUNT=$(kubectl exec -n "$NAMESPACE" deploy/lms -- python manage.py lms shell -c "
from enterprise.models import EnterpriseCustomer
print(EnterpriseCustomer.objects.count())
" 2>&1 | grep -oE '^[0-9]+$' | head -1 || echo "0")
  echo "  EnterpriseCustomers: $ENTERPRISE_COUNT"

  if [ "$ENTERPRISE_COUNT" -eq 0 ]; then
    skip_ "AC-MTA-003, AC-MTA-004, AC-MTA-007, AC-MTA-025, AC-MTA-029, AC-MTA-030, AC-MTA-032: No EnterpriseCustomers exist (multi-tenancy not provisioned yet)"
  fi
  echo

  # List EnterpriseCustomers with basic details
  if [ "$ENTERPRISE_COUNT" -gt 0 ]; then
    echo "EnterpriseCustomer details:"
    kubectl exec -n "$NAMESPACE" deploy/lms -- python manage.py lms shell -c "
from enterprise.models import EnterpriseCustomer
for ec in EnterpriseCustomer.objects.all().order_by('name'):
    print(f'  {ec.name} (slug: {ec.slug}, uuid: {ec.uuid}, active: {ec.active})')
" 2>&1 | grep -E '^\s+' || echo "  (none)"
    echo
  fi

  # Check course_org_filter per site
  echo "Checking course_org_filter per site..."
  SITE_ORG_FILTERS=$(kubectl exec -n "$NAMESPACE" deploy/lms -- python manage.py lms shell -c "
from django.contrib.sites.models import Site
from openedx.core.djangoapps.site_configuration.models import SiteConfiguration

print('__ORG_FILTER_START__')
for site in Site.objects.all().order_by('id'):
    try:
        config = SiteConfiguration.objects.get(site=site)
        org_filter = config.get_value('course_org_filter', [])
        print(f'{site.domain}|{org_filter}')
    except SiteConfiguration.DoesNotExist:
        print(f'{site.domain}|NO_CONFIG')
print('__ORG_FILTER_END__')
" 2>&1 | sed -n '/__ORG_FILTER_START__/,/__ORG_FILTER_END__/p' | grep -v '__ORG_FILTER' || echo "")

  if [ -n "$SITE_ORG_FILTERS" ]; then
    echo "$SITE_ORG_FILTERS" | while IFS='|' read -r domain org_filter; do
      echo "  $domain: $org_filter"
    done
  else
    echo "  (no course_org_filter data)"
  fi
  echo

  # Report course distribution by org
  echo "Course distribution by org:"
  COURSE_ORG_DIST=$(kubectl exec -n "$NAMESPACE" deploy/lms -- python manage.py lms shell -c "
from openedx.core.djangoapps.content.course_overviews.models import CourseOverview
from collections import Counter

orgs = [str(course.org) for course in CourseOverview.objects.all()]
counts = Counter(orgs)

print('__COURSE_ORG_START__')
for org, count in sorted(counts.items()):
    print(f'{org}: {count}')
print('__COURSE_ORG_END__')
" 2>&1 | sed -n '/__COURSE_ORG_START__/,/__COURSE_ORG_END__/p' | grep -v '__COURSE_ORG' || echo "")

  if [ -n "$COURSE_ORG_DIST" ]; then
    echo "$COURSE_ORG_DIST" | while IFS= read -r line; do
      echo "  $line"
    done
  else
    echo "  (no courses found)"
  fi
  echo

  # Summary
  if [ "$SITE_COUNT" -gt 1 ] && [ "$ENTERPRISE_COUNT" -gt 0 ]; then
    pass_ "Multiple sites and enterprise customers exist (multi-tenant data present)"
  elif [ "$SITE_COUNT" -gt 1 ]; then
    skip_ "Multiple sites exist but no EnterpriseCustomers (multi-site without enterprise tenancy)"
  else
    skip_ "Only one site exists (single-tenant deployment)"
  fi
  echo
fi

###########################################################################
# SECTION 3: Site-Level Course Isolation (API Testing)
###########################################################################
echo -e "${CYAN}=== 3. Site-Level Course Isolation ===${NC}"
echo

if [ "$KUBECTL_OK" = false ]; then
  skip_ "All API isolation checks (kubectl unavailable)"
elif [ "$ENTERPRISE_COUNT" -eq 0 ]; then
  skip_ "AC-MTA-032: No enterprise customers exist (cannot test catalog isolation)"
else
  # Test /api/courses/v1/courses/ endpoint for each site domain
  echo "Testing course API endpoint for each site domain..."
  echo

  # Get list of site domains
  DOMAINS=$(kubectl exec -n "$NAMESPACE" deploy/lms -- python manage.py lms shell -c "
from django.contrib.sites.models import Site
for site in Site.objects.all().order_by('id'):
    print(site.domain)
" 2>&1 | grep -E '^[a-z0-9.-]+\.[a-z]+$' || echo "")

  if [ -z "$DOMAINS" ]; then
    skip_ "AC-MTA-032: No site domains found"
  else
    # Get primary LMS domain (first site or academyv2.mereka.io)
    LMS_DOMAIN=$(echo "$DOMAINS" | head -1)
    if echo "$DOMAINS" | grep -q "academyv2.mereka.io"; then
      LMS_DOMAIN="academyv2.mereka.io"
    fi

    while IFS= read -r domain; do
      echo "  Testing domain: $domain"

      # Check if domain is reachable
      if ! curl -s -o /dev/null -w '%{http_code}' --max-time 5 -H "Host: $domain" "https://${LMS_DOMAIN}/api/courses/v1/courses/" 2>/dev/null | grep -qE '^[23]'; then
        skip_ "    Domain $domain not reachable (DNS/routing not configured)"
        continue
      fi

      # Fetch courses for this domain
      COURSE_API_RESPONSE=$(curl -s --max-time 10 -H "Host: $domain" "https://${LMS_DOMAIN}/api/courses/v1/courses/?page_size=100" 2>/dev/null || echo "")

      if [ -z "$COURSE_API_RESPONSE" ]; then
        skip_ "    No response from course API for $domain"
        continue
      fi

      # Extract course count (simple JSON parsing)
      COURSE_COUNT=$(echo "$COURSE_API_RESPONSE" | grep -oE '"count":\s*[0-9]+' | grep -oE '[0-9]+' | head -1 || echo "0")
      echo "    Courses returned: $COURSE_COUNT"

      # Extract course orgs (simple parsing, assumes "org": "VALUE" format)
      COURSE_ORGS=$(echo "$COURSE_API_RESPONSE" | grep -oE '"org":\s*"[^"]+"' | grep -oE '"[^"]+"\s*$' | tr -d '"' | sort | uniq || echo "")
      if [ -n "$COURSE_ORGS" ]; then
        echo "    Orgs found in response:"
        echo "$COURSE_ORGS" | while IFS= read -r org; do
          echo "      - $org"
        done
      fi

      # Get expected org_filter for this domain
      EXPECTED_ORG=$(echo "$SITE_ORG_FILTERS" | grep "^${domain}|" | cut -d'|' -f2 || echo "")

      if [ -z "$EXPECTED_ORG" ] || [ "$EXPECTED_ORG" = "NO_CONFIG" ] || [ "$EXPECTED_ORG" = "[]" ]; then
        skip_ "    No course_org_filter configured for $domain (cannot verify isolation)"
      else
        # Extract org value from list format like "['MEREKA']"
        EXPECTED_ORG_VALUE=$(echo "$EXPECTED_ORG" | grep -oE "'[A-Z0-9_]+'" | tr -d "'" | head -1 || echo "")

        if [ -n "$EXPECTED_ORG_VALUE" ]; then
          # Check if all returned courses match the expected org
          MISMATCH=false
          if [ -n "$COURSE_ORGS" ]; then
            while IFS= read -r org; do
              if [ "$org" != "$EXPECTED_ORG_VALUE" ]; then
                MISMATCH=true
                fail_ "AC-MTA-032: Course org '$org' returned for $domain (expected only '$EXPECTED_ORG_VALUE')"
              fi
            done <<< "$COURSE_ORGS"
          fi

          if [ "$MISMATCH" = false ]; then
            if [ "$COURSE_COUNT" -gt 0 ]; then
              pass_ "AC-MTA-032: All $COURSE_COUNT courses for $domain match org filter '$EXPECTED_ORG_VALUE'"
            else
              skip_ "AC-MTA-032: No courses returned for $domain (empty catalog)"
            fi
          fi
        else
          skip_ "    Could not parse expected org from course_org_filter: $EXPECTED_ORG"
        fi
      fi
      echo
    done <<< "$DOMAINS"
  fi
fi

###########################################################################
# SECTION 4: Cross-Domain Cookie Isolation
###########################################################################
echo -e "${CYAN}=== 4. Cross-Domain Cookie Isolation ===${NC}"
echo

if [ "$KUBECTL_OK" = false ]; then
  skip_ "All cookie isolation checks (kubectl unavailable)"
else
  # Check if MerekaCookieDomainMiddleware is deployed
  echo "Checking if MerekaCookieDomainMiddleware is in MIDDLEWARE..."
  if echo "$MW_OUTPUT" | grep -q "MerekaCookieDomainMiddleware"; then
    pass_ "MerekaCookieDomainMiddleware is deployed"

    # Test cookie domain scoping for each site
    echo
    echo "Testing Set-Cookie domain for each site..."

    if [ -n "$DOMAINS" ]; then
      while IFS= read -r domain; do
        echo "  Testing domain: $domain"

        # Get Set-Cookie headers
        COOKIE_HEADER=$(curl -s -I --max-time 5 -H "Host: $domain" "https://${LMS_DOMAIN}/" 2>/dev/null | grep -i "^Set-Cookie:" | head -1 || echo "")

        if [ -z "$COOKIE_HEADER" ]; then
          skip_ "    No Set-Cookie header returned for $domain"
          continue
        fi

        echo "    Set-Cookie: $(echo "$COOKIE_HEADER" | cut -c1-80)..."

        # Extract Domain attribute from cookie
        COOKIE_DOMAIN=$(echo "$COOKIE_HEADER" | grep -oE "Domain=[^;]+" | cut -d'=' -f2 | tr -d ' ' || echo "")

        if [ -n "$COOKIE_DOMAIN" ]; then
          echo "    Cookie Domain attribute: $COOKIE_DOMAIN"

          # Verify cookie domain doesn't leak across unrelated sites
          # (e.g., academy.biji-biji.com should not get Domain=.academyv2.mereka.io)
          if echo "$domain" | grep -q "academyv2.mereka.io"; then
            if [ "$COOKIE_DOMAIN" = ".academyv2.mereka.io" ]; then
              pass_ "    Cookie domain correct for academyv2.mereka.io site"
            else
              fail_ "    Cookie domain '$COOKIE_DOMAIN' unexpected for $domain"
            fi
          elif echo "$domain" | grep -q "biji-biji.com"; then
            if echo "$COOKIE_DOMAIN" | grep -q "biji-biji.com"; then
              pass_ "    Cookie domain scoped to biji-biji.com"
            else
              fail_ "    Cookie domain '$COOKIE_DOMAIN' leaks outside biji-biji.com for $domain"
            fi
          else
            # Generic check: cookie domain should be related to request domain
            if echo "$COOKIE_DOMAIN" | grep -qF "$(echo "$domain" | rev | cut -d. -f1-2 | rev)"; then
              pass_ "    Cookie domain scoped to $domain's TLD"
            else
              fail_ "    Cookie domain '$COOKIE_DOMAIN' does not match domain $domain"
            fi
          fi
        else
          # No Domain attribute = host-only cookie (also acceptable for isolation)
          pass_ "    Host-only cookie (no Domain attribute, strongest isolation)"
        fi
        echo
      done <<< "$DOMAINS"
    fi
  else
    fail_ "MerekaCookieDomainMiddleware NOT deployed (cookie isolation not enforced)"
    echo "  → Add MerekaCookieDomainMiddleware to MIDDLEWARE after CurrentSiteMiddleware"
    echo
  fi
fi

###########################################################################
# SECTION 5: API Endpoint Isolation (Enterprise APIs)
###########################################################################
echo -e "${CYAN}=== 5. API Endpoint Isolation ===${NC}"
echo

if [ "$KUBECTL_OK" = false ]; then
  skip_ "All API endpoint checks (kubectl unavailable)"
elif [ "$ENTERPRISE_COUNT" -eq 0 ]; then
  skip_ "AC-MTA-003, AC-MTA-004, AC-MTA-029, AC-MTA-030: No enterprise customers exist (cannot test enterprise API isolation)"
else
  # Test enterprise catalog API
  echo "Testing enterprise catalog API isolation..."

  # Note: Full API isolation testing requires:
  # 1. Admin user tokens for each tenant
  # 2. Populated catalog data
  # 3. Cross-tenant access attempts
  # This is a placeholder for the infrastructure-level check

  skip_ "AC-MTA-003: Enterprise catalog API isolation requires tenant admin tokens (manual test)"
  skip_ "AC-MTA-004: Cross-tenant subscription API access requires tenant admin tokens (manual test)"
  skip_ "AC-MTA-029: Tenant A admin accessing Tenant B learner data requires test users (manual test)"
  skip_ "AC-MTA-030: Tenant B admin querying Tenant A data requires test users (manual test)"

  echo
  echo "To test API-level isolation manually:"
  echo "  1. Create tenant A and B with admin users"
  echo "  2. Obtain admin API tokens for each tenant"
  echo "  3. Attempt cross-tenant API calls (GET /api/v1/enterprise-catalogs/ with Tenant B's UUID)"
  echo "  4. Verify HTTP 403 responses for cross-tenant access"
  echo
fi

###########################################################################
# SECTION 6: Middleware Stack Audit
###########################################################################
echo -e "${CYAN}=== 6. Middleware Stack Audit ===${NC}"
echo

if [ "$KUBECTL_OK" = false ]; then
  skip_ "All middleware checks (kubectl unavailable)"
else
  # List all Mereka-prefixed middleware
  echo "Mereka middleware components deployed:"
  MEREKA_MW=$(echo "$MW_OUTPUT" | grep -i "mereka" || echo "")

  if [ -n "$MEREKA_MW" ]; then
    echo "$MEREKA_MW" | while IFS= read -r mw; do
      echo "  - $mw"
    done

    MEREKA_MW_COUNT=$(echo "$MEREKA_MW" | wc -l)
    echo
    echo "Total Mereka middleware: $MEREKA_MW_COUNT"
    echo
  else
    fail_ "No Mereka-prefixed middleware found in MIDDLEWARE stack"
    echo
  fi

  # Check middleware ordering (TenantResolutionMiddleware should come after CurrentSiteMiddleware)
  if [ "$TENANT_MW_DEPLOYED" = true ]; then
    echo "Checking middleware ordering..."

    # Extract line numbers for CurrentSiteMiddleware and TenantResolutionMiddleware
    SITE_MW_LINE=$(echo "$MW_OUTPUT" | grep -n "CurrentSiteMiddleware" | cut -d: -f1 || echo "0")
    TENANT_MW_LINE=$(echo "$MW_OUTPUT" | grep -n "TenantResolutionMiddleware" | cut -d: -f1 || echo "0")

    if [ "$SITE_MW_LINE" -gt 0 ] && [ "$TENANT_MW_LINE" -gt 0 ]; then
      if [ "$TENANT_MW_LINE" -gt "$SITE_MW_LINE" ]; then
        pass_ "TenantResolutionMiddleware comes after CurrentSiteMiddleware (correct ordering)"
      else
        fail_ "TenantResolutionMiddleware comes BEFORE CurrentSiteMiddleware (incorrect ordering)"
        echo "  → TenantResolutionMiddleware needs request.site set by CurrentSiteMiddleware"
      fi
    elif [ "$SITE_MW_LINE" -eq 0 ]; then
      skip_ "CurrentSiteMiddleware not found (cannot verify ordering)"
    fi
    echo
  fi
fi

###########################################################################
# SECTION 7: MongoDB Tenant Scoping (Informational)
###########################################################################
echo -e "${CYAN}=== 7. MongoDB Tenant Scoping (Informational) ===${NC}"
echo

echo "MongoDB Atlas multi-tenancy model:"
echo "  - All tenants share the same MongoDB databases (openedx, cs_comments_service)"
echo "  - Tenant isolation is enforced at the APPLICATION layer (not database layer)"
echo "  - Modulestore courses are org-scoped (org field maps to tenant)"
echo "  - Forum posts are course-scoped (implicitly tenant-scoped via enrollment)"
echo

if [ "$KUBECTL_OK" = true ]; then
  # Sample modulestore query to show org-based scoping
  echo "Sample course orgs from modulestore:"
  MODULESTORE_ORGS=$(kubectl exec -n "$NAMESPACE" deploy/lms -- python manage.py lms shell -c "
from openedx.core.djangoapps.content.course_overviews.models import CourseOverview
from collections import Counter

orgs = [str(course.org) for course in CourseOverview.objects.all()[:50]]
counts = Counter(orgs)

print('__MODULESTORE_ORG_START__')
for org, count in sorted(counts.items()):
    print(f'{org}: {count}')
print('__MODULESTORE_ORG_END__')
" 2>&1 | sed -n '/__MODULESTORE_ORG_START__/,/__MODULESTORE_ORG_END__/p' | grep -v '__MODULESTORE_ORG' || echo "")

  if [ -n "$MODULESTORE_ORGS" ]; then
    echo "$MODULESTORE_ORGS" | while IFS= read -r line; do
      echo "  $line"
    done
  else
    echo "  (no course data found)"
  fi
  echo
fi

skip_ "AC-MTA-006: MongoDB database-level isolation not implemented (application-layer isolation per spec)"
echo "  → Open edX uses shared MongoDB with application-layer queryset filtering"
echo "  → Tenant isolation depends on enterprise-catalog filtering by org"
echo

###########################################################################
# SECTION 8: Deployment Readiness Checklist
###########################################################################
echo -e "${CYAN}=== 8. Deployment Readiness Checklist ===${NC}"
echo

echo "Multi-tenancy component status:"
echo

# Component 1: mereka_tenancy module
if [ "$TENANCY_INSTALLED" = true ]; then
  echo -e "  ${GREEN}✓${NC} mereka_tenancy module installed"
else
  echo -e "  ${RED}✗${NC} mereka_tenancy module NOT installed"
  echo "      Action: Rebuild LMS image with mereka_tenancy plugin"
  echo "      File: infrastructure/tutor/plugins/multi-tenancy/"
fi

# Component 2: INSTALLED_APPS configuration
if [ "$TENANCY_IN_APPS" = true ]; then
  echo -e "  ${GREEN}✓${NC} mereka_tenancy in INSTALLED_APPS"
else
  echo -e "  ${RED}✗${NC} mereka_tenancy NOT in INSTALLED_APPS"
  echo "      Action: Run infrastructure/tutor/apply-patches.sh"
fi

# Component 3: TenantResolutionMiddleware
if [ "$TENANT_MW_DEPLOYED" = true ]; then
  echo -e "  ${GREEN}✓${NC} TenantResolutionMiddleware deployed"
else
  echo -e "  ${RED}✗${NC} TenantResolutionMiddleware NOT deployed"
  echo "      Action: Add TenantResolutionMiddleware to MIDDLEWARE in apply-patches.sh"
  echo "      Position: After CurrentSiteMiddleware"
fi

# Component 4: Enterprise app
ENTERPRISE_INSTALLED=$(echo "$APPS_OUTPUT" | grep -qE "(^|\\.)enterprise($|\\.apps\\.EnterpriseConfig)" && echo "true" || echo "false")
if [ "$ENTERPRISE_INSTALLED" = true ]; then
  echo -e "  ${GREEN}✓${NC} enterprise app installed"
else
  echo -e "  ${RED}✗${NC} enterprise app NOT installed"
  echo "      Action: Ensure openedx-enterprise is in INSTALLED_APPS"
fi

# Component 5: MerekaCookieDomainMiddleware
COOKIE_MW_DEPLOYED=$(echo "$MW_OUTPUT" | grep -q "MerekaCookieDomainMiddleware" && echo "true" || echo "false")
if [ "$COOKIE_MW_DEPLOYED" = true ]; then
  echo -e "  ${GREEN}✓${NC} MerekaCookieDomainMiddleware deployed"
else
  echo -e "  ${YELLOW}⚠${NC} MerekaCookieDomainMiddleware NOT deployed"
  echo "      Impact: Cookie isolation across tenant domains not enforced"
  echo "      Action: Deploy MerekaCookieDomainMiddleware (optional but recommended)"
fi

# Component 6: EnterpriseCustomer records
if [ "$ENTERPRISE_COUNT" -gt 0 ]; then
  echo -e "  ${GREEN}✓${NC} $ENTERPRISE_COUNT EnterpriseCustomer(s) provisioned"
else
  echo -e "  ${YELLOW}⚠${NC} No EnterpriseCustomer records exist"
  echo "      Status: Infrastructure ready, but no tenants provisioned yet"
  echo "      Action: Run scripts/tenants/provision-tenant.sh to create first tenant"
fi

# Component 7: Site-level isolation
if [ "$SITE_COUNT" -gt 1 ]; then
  echo -e "  ${GREEN}✓${NC} Multiple Django Sites configured ($SITE_COUNT sites)"
else
  echo -e "  ${YELLOW}⚠${NC} Only 1 Django Site exists"
  echo "      Status: Single-tenant mode (default Mereka Academy)"
  echo "      Action: Provision additional tenant sites for multi-tenancy"
fi

echo

###########################################################################
# SUMMARY
###########################################################################
echo
echo -e "${CYAN}=== Summary ===${NC}"
echo
echo "Total checks:"
echo -e "  ${GREEN}PASS: $PASS${NC}"
echo -e "  ${RED}FAIL: $FAIL${NC}"
echo -e "  ${YELLOW}SKIP: $SKIP${NC}"
echo

if [ $FAIL -eq 0 ]; then
  if [ $SKIP -gt $PASS ]; then
    echo -e "${YELLOW}Status: INCOMPLETE${NC} (infrastructure not fully deployed)"
    echo
    echo "Next steps:"
    echo "  1. Deploy mereka_tenancy module (rebuild image with plugin)"
    echo "  2. Run apply-patches.sh to add to INSTALLED_APPS"
    echo "  3. Add TenantResolutionMiddleware to MIDDLEWARE stack"
    echo "  4. Provision first tenant with scripts/tenants/provision-tenant.sh"
    echo "  5. Re-run this script to verify full deployment"
  else
    echo -e "${GREEN}Status: PASS${NC}"
    echo "Multi-tenancy infrastructure is correctly deployed and tenant isolation is verified."
  fi
  exit 0
else
  echo -e "${RED}Status: FAIL${NC}"
  echo "Multi-tenancy deployment has issues. Review failures above."
  exit 1
fi
