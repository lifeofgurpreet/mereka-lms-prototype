"""
Management command to offboard a tenant.

@spec: multi-tenancy-architecture_spec.md
@covers: AC-TEN-014, AC-TEN-015, AC-TEN-016, AC-TEN-020, AC-TEN-021
"""
import json
import logging
import os
from datetime import datetime, timedelta

from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = 'Offboard a tenant: deactivate, export data, optionally delete after grace period'

    def add_arguments(self, parser):
        parser.add_argument('--slug', required=True, help='Tenant slug to offboard')
        parser.add_argument('--export-dir', default='', help='Directory for data export')
        parser.add_argument('--force-delete', action='store_true',
                            help='Execute data deletion (only after grace period)')
        parser.add_argument('--grace-days', type=int, default=30,
                            help='Grace period in days (default: 30)')
        parser.add_argument('--actor', default='system',
                            help='Who initiated the offboarding')
        parser.add_argument('--dry-run', action='store_true',
                            help='Show what would be done')

    def handle(self, *args, **options):
        slug = options['slug']
        export_dir = options['export_dir'] or f'/tmp/tenant-export-{slug}'
        force_delete = options['force_delete']
        grace_days = options['grace_days']
        actor = options['actor']
        dry_run = options['dry_run']

        audit_log = {
            'action': 'offboard',
            'tenant_slug': slug,
            'actor': actor,
            'timestamp': datetime.utcnow().isoformat() + 'Z',
            'grace_days': grace_days,
            'dry_run': dry_run,
            'force_delete': force_delete,
            'steps': [],
        }

        def log_step(name, result, detail=''):
            entry = {'step': name, 'status': result, 'detail': detail,
                     'timestamp': datetime.utcnow().isoformat() + 'Z'}
            audit_log['steps'].append(entry)
            prefix = 'DRY RUN: ' if dry_run else ''
            self.stdout.write(f'  {prefix}[{name}] {result}' +
                              (f' ({detail})' if detail else ''))

        # Find tenant mapping
        from openedx_tenant_cache.models import TenantSiteMapping, TenantSiteConfiguration

        mapping = TenantSiteMapping.objects.filter(slug=slug).first()
        if not mapping:
            raise CommandError(f"Tenant '{slug}' not found")

        enterprise_uuid = str(mapping.enterprise_customer_uuid)
        audit_log['enterprise_customer_uuid'] = enterprise_uuid
        audit_log['tenant_uuid'] = enterprise_uuid

        self.stdout.write(f'\n=== Offboarding Tenant: {mapping.name} ({slug}) ===')
        self.stdout.write(f'  UUID:   {enterprise_uuid}')
        self.stdout.write(f'  Actor:  {actor}')
        self.stdout.write(f'  Mode:   {"DELETE" if force_delete else "DEACTIVATE"}')
        self.stdout.write('')

        if force_delete:
            self._handle_deletion(mapping, enterprise_uuid, slug, grace_days,
                                  dry_run, audit_log, log_step, export_dir)
        else:
            self._handle_deactivation(mapping, enterprise_uuid, slug,
                                      dry_run, audit_log, log_step, export_dir)

        # Write audit log
        if not dry_run:
            os.makedirs(export_dir, exist_ok=True)
            audit_path = os.path.join(export_dir, f'offboarding-audit-{slug}.json')
            with open(audit_path, 'w') as f:
                json.dump(audit_log, f, indent=2)
            log_step('write_audit_log', 'ok', audit_path)
        else:
            log_step('write_audit_log', 'skipped', 'dry run')

        self.stdout.write('')
        self.stdout.write(json.dumps(audit_log, indent=2))

    def _handle_deactivation(self, mapping, enterprise_uuid, slug,
                              dry_run, audit_log, log_step, export_dir):
        """Deactivate tenant and export data."""
        # Step 1: Deactivate TenantSiteMapping
        if mapping.is_active:
            if not dry_run:
                mapping.is_active = False
                mapping.save(update_fields=['is_active', 'updated_at'])
            log_step('deactivate_mapping', 'deactivated')
        else:
            log_step('deactivate_mapping', 'already_inactive')

        # Step 2: Deactivate TenantSiteConfiguration
        try:
            config = mapping.site_config
            if config.is_active:
                if not dry_run:
                    config.is_active = False
                    config.save(update_fields=['is_active', 'updated_at'])
                log_step('deactivate_config', 'deactivated')
            else:
                log_step('deactivate_config', 'already_inactive')
        except Exception:
            log_step('deactivate_config', 'skipped', 'no config found')

        # Step 3: Deactivate EnterpriseCustomer
        try:
            from enterprise.models import EnterpriseCustomer
            ec = EnterpriseCustomer.objects.filter(uuid=enterprise_uuid).first()
            if ec and ec.active:
                if not dry_run:
                    ec.active = False
                    ec.save(update_fields=['active'])
                log_step('deactivate_enterprise', 'deactivated')
            elif ec:
                log_step('deactivate_enterprise', 'already_inactive')
            else:
                log_step('deactivate_enterprise', 'skipped', 'not found')
        except ImportError:
            log_step('deactivate_enterprise', 'skipped', 'edx-enterprise not installed')

        # Step 4: Disable SSO
        try:
            from enterprise.models import EnterpriseCustomer
            ec = EnterpriseCustomer.objects.filter(uuid=enterprise_uuid).first()
            idp_slug = getattr(ec, 'identity_provider', '') if ec else ''
            if idp_slug:
                try:
                    from third_party_auth.models import SAMLProviderConfig
                    saml = SAMLProviderConfig.objects.filter(slug=idp_slug).first()
                    if saml and saml.enabled:
                        if not dry_run:
                            saml.enabled = False
                            saml.save(update_fields=['enabled'])
                        log_step('disable_sso', 'disabled', f'SAML: {idp_slug}')
                    else:
                        log_step('disable_sso', 'skipped', 'already disabled or not found')
                except ImportError:
                    log_step('disable_sso', 'skipped', 'third_party_auth not installed')
            else:
                log_step('disable_sso', 'skipped', 'no IdP configured')
        except ImportError:
            log_step('disable_sso', 'skipped', 'edx-enterprise not installed')

        # Step 5: Export data summary
        export_data = {
            'tenant_slug': slug,
            'enterprise_customer_uuid': enterprise_uuid,
            'name': mapping.name,
            'exported_at': audit_log['timestamp'],
            'user_count': 0,
            'enrollment_count': 0,
        }
        try:
            from enterprise.models import EnterpriseCustomerUser
            export_data['user_count'] = EnterpriseCustomerUser.objects.filter(
                enterprise_customer__uuid=enterprise_uuid
            ).count()
        except (ImportError, Exception):
            pass
        try:
            from enterprise.models import EnterpriseCourseEnrollment
            export_data['enrollment_count'] = EnterpriseCourseEnrollment.objects.filter(
                enterprise_customer_user__enterprise_customer__uuid=enterprise_uuid
            ).count()
        except (ImportError, Exception):
            pass

        if not dry_run:
            os.makedirs(export_dir, exist_ok=True)
            export_path = os.path.join(export_dir, f'export-{slug}.json')
            with open(export_path, 'w') as f:
                json.dump(export_data, f, indent=2)
            log_step('export_data', 'ok', export_path)
        else:
            log_step('export_data', 'skipped', 'dry run')

        # Step 6: Flush branding cache
        try:
            from openedx_tenant_cache.cache import tenant_cache_delete
            tenant_cache_delete(enterprise_uuid, 'branding', 'mfe_config')
            log_step('flush_branding_cache', 'ok')
        except Exception:
            log_step('flush_branding_cache', 'skipped')

        audit_log['outcome'] = 'deactivated'

    def _handle_deletion(self, mapping, enterprise_uuid, slug, grace_days,
                          dry_run, audit_log, log_step, export_dir):
        """Delete tenant data after grace period verification."""
        # Step 1: Check grace period
        if mapping.is_active:
            raise CommandError(
                f"Tenant '{slug}' is still active. Deactivate first "
                f"(run without --force-delete)."
            )

        deactivated_at = mapping.updated_at
        if deactivated_at:
            # Make timezone-naive for comparison
            if hasattr(deactivated_at, 'replace') and deactivated_at.tzinfo:
                from django.utils import timezone
                deactivated_at = deactivated_at.replace(tzinfo=None)

            grace_expiry = deactivated_at + timedelta(days=grace_days)
            now = datetime.utcnow()

            if now < grace_expiry:
                days_remaining = (grace_expiry - now).days
                log_step('grace_period_check', 'blocked',
                         f'{days_remaining} days remaining')
                audit_log['outcome'] = 'blocked_grace_period'
                raise CommandError(
                    f"Grace period not expired. {days_remaining} days remaining "
                    f"(expires {grace_expiry.isoformat()}Z). "
                    f"PDPA/GDPR requires {grace_days}-day retention."
                )

            log_step('grace_period_check', 'passed', 'grace period expired')
        else:
            log_step('grace_period_check', 'warning', 'no deactivation date found')

        # Step 2: Delete enterprise catalog records
        try:
            from enterprise.models import EnterpriseCustomerCatalog
            if not dry_run:
                count = EnterpriseCustomerCatalog.objects.filter(
                    enterprise_customer__uuid=enterprise_uuid
                ).delete()[0]
                log_step('delete_catalogs', 'deleted', f'{count} records')
            else:
                count = EnterpriseCustomerCatalog.objects.filter(
                    enterprise_customer__uuid=enterprise_uuid
                ).count()
                log_step('delete_catalogs', 'would_delete', f'{count} records')
        except ImportError:
            log_step('delete_catalogs', 'skipped', 'edx-enterprise not installed')

        # Step 3: Delete ClickHouse events
        try:
            from event_sink_clickhouse.sinks import ClickHouseConnection
            conn = ClickHouseConnection()
            if not dry_run:
                conn.execute(
                    f"ALTER TABLE xapi_events_all DELETE "
                    f"WHERE enterprise_customer_uuid = '{enterprise_uuid}'"
                )
                log_step('delete_clickhouse_events', 'deleted',
                         f'uuid={enterprise_uuid}')
            else:
                result = conn.execute(
                    f"SELECT count() FROM xapi_events_all "
                    f"WHERE enterprise_customer_uuid = '{enterprise_uuid}'"
                )
                count = result[0][0] if result else 0
                log_step('delete_clickhouse_events', 'would_delete',
                         f'{count} events')
        except ImportError:
            log_step('delete_clickhouse_events', 'skipped',
                     'ClickHouse not available')
        except Exception as e:
            log_step('delete_clickhouse_events', 'error', str(e))

        # Step 4: Delete TenantSiteConfiguration
        try:
            config = mapping.site_config
            if not dry_run:
                config.delete()
            log_step('delete_site_config', 'deleted')
        except Exception:
            log_step('delete_site_config', 'skipped', 'no config')

        # Step 5: Delete TenantSiteMapping
        if not dry_run:
            mapping.delete()
        log_step('delete_tenant_mapping', 'deleted', f'slug={slug}')

        # Step 6: Flush all Redis cache keys
        try:
            from openedx_tenant_cache.cache import tenant_cache_clear_all
            if not dry_run:
                cleared = tenant_cache_clear_all(enterprise_uuid)
                log_step('flush_redis_cache', 'cleared', f'{cleared} keys')
            else:
                log_step('flush_redis_cache', 'would_clear', 'all tenant keys')
        except Exception as e:
            log_step('flush_redis_cache', 'error', str(e))

        # Step 7: Delete EnterpriseCustomer (last — cascade)
        try:
            from enterprise.models import EnterpriseCustomer
            ec = EnterpriseCustomer.objects.filter(uuid=enterprise_uuid).first()
            if ec:
                if not dry_run:
                    ec.delete()
                log_step('delete_enterprise_customer', 'deleted',
                         f'uuid={enterprise_uuid}')
            else:
                log_step('delete_enterprise_customer', 'skipped', 'not found')
        except ImportError:
            log_step('delete_enterprise_customer', 'skipped',
                     'edx-enterprise not installed')

        audit_log['outcome'] = 'fully_deleted' if not dry_run else 'dry_run'
