"""
URL routing for tenant cache API.

@spec: multi-tenancy-architecture_spec.md
"""

from django.urls import path

from .views import TenantBrandingView, TenantListView

app_name = 'openedx_tenant_cache'

urlpatterns = [
    path('tenants/', TenantListView.as_view(), name='tenant-list'),
    path(
        'tenants/<slug:tenant_slug>/branding/',
        TenantBrandingView.as_view(),
        name='tenant-branding',
    ),
]
