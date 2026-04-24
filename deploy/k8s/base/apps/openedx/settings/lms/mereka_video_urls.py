"""
Root URL overrides for Mereka video APIs.

These routes are mounted through ROOT_URLCONF_OVERRIDES because several custom
apps expose relative urlpatterns but are not otherwise attached to the LMS
root URLConf in our runtime bundle.
"""

from importlib import import_module

from django.urls import include, path


def _mount_if_importable(
    urlpatterns,
    module_name: str,
    prefix: str,
    importer=import_module,
    include_func=include,
    path_func=path,
):
    try:
        importer(module_name)
    except ImportError:
        return

    urlpatterns.append(path_func(prefix, include_func(module_name)))


urlpatterns = []
_mount_if_importable(urlpatterns, "openedx_video_pipeline.urls", "api/video-pipeline/")
_mount_if_importable(urlpatterns, "openedx_video_analytics.urls", "api/video/v1/")
_mount_if_importable(urlpatterns, "openedx_video_protection.urls", "api/mux/protection/")
