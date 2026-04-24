# mereka_tenancy — Multi-tenancy extensions for Open edX EnterpriseCustomer.
#
# This Django app is installed into the LMS via Tutor patches (apply-patches.sh).
# It extends EnterpriseCustomer with a TenantConfig model (OneToOneField) and
# provides TenantResolutionMiddleware for per-request tenant context.
#
# See: specs/multi-tenancy-architecture_spec.md
default_app_config = "mereka_tenancy.apps.MerekaTenancyConfig"
