"""URL routing for Content Libraries v2 extensions."""
from django.urls import path
from .views import (
    LibraryListView, LibraryPublishView, LibraryRollbackView,
    LibraryVersionListView, LibrarySoftDeleteView,
    LibraryUpdateNotificationsView, OrphanCheckView,
    LibraryRoleView, LibraryPublicReadView,
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
]
