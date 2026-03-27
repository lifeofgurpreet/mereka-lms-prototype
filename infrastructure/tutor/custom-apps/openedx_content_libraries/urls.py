"""URL routing for Content Libraries v2 extensions."""
from django.urls import path
from .views import (
    LibraryListView, LibraryPublishView, LibraryRollbackView,
    LibraryVersionListView, LibrarySoftDeleteView,
    LibraryUpdateNotificationsView, OrphanCheckView,
    LibraryRoleView, LibraryPublicReadView,
    LibrarySearchView, LibraryUsageReportView, LibraryAnalyticsSummaryView,
    LibraryQuotaView, LibraryExportImportView, LibrarySecurityAuditView,
)

app_name = 'openedx_content_libraries'

urlpatterns = [
    path('libraries/', LibraryListView.as_view(), name='library-list'),
    path('libraries/<path:library_key>/publish/',
         LibraryPublishView.as_view(), name='library-publish'),
    path('libraries/<path:library_key>/rollback/',
         LibraryRollbackView.as_view(), name='library-rollback'),
    path('libraries/<path:library_key>/versions/',
         LibraryVersionListView.as_view(), name='library-versions'),
    path('libraries/<path:library_key>/delete/',
         LibrarySoftDeleteView.as_view(), name='library-delete'),
    path('libraries/<path:library_key>/orphans/',
         OrphanCheckView.as_view(), name='library-orphans'),
    path('libraries/updates/',
         LibraryUpdateNotificationsView.as_view(), name='library-updates'),

    # Phase 2: Tenant Libraries (AC-LIB-014 through AC-LIB-019)
    path('libraries/<path:library_key>/roles/',
         LibraryRoleView.as_view(), name='library-roles'),
    path('libraries/<path:library_key>/public-read/',
         LibraryPublicReadView.as_view(), name='library-public-read'),

    # Phase 3: Scale, Search, Analytics (AC-LIB-020 through AC-LIB-025)
    path('libraries/search/',
         LibrarySearchView.as_view(), name='library-search'),
    path('libraries/analytics/',
         LibraryAnalyticsSummaryView.as_view(), name='library-analytics-summary'),
    path('libraries/<path:library_key>/usage/',
         LibraryUsageReportView.as_view(), name='library-usage-report'),

    # Phase 3-4: Multi-Tenant Scale + Hardening (AC-LIB-026 through AC-LIB-032)
    path('libraries/quotas/',
         LibraryQuotaView.as_view(), name='library-quotas'),
    path('libraries/import/',
         LibraryExportImportView.as_view(), name='library-import'),
    path('libraries/<path:library_key>/export/',
         LibraryExportImportView.as_view(), name='library-export'),
    path('libraries/<path:library_key>/security-audit/',
         LibrarySecurityAuditView.as_view(), name='library-security-audit'),
]
