"""
Unit tests for mereka_video_urls.py
"""

import os
import sys
import unittest


MODULE_DIR = os.path.dirname(os.path.abspath(__file__))
if MODULE_DIR not in sys.path:
    sys.path.insert(0, MODULE_DIR)


class TestMerekaVideoUrls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        sys.modules.pop("mereka_video_urls", None)
        import mereka_video_urls as mvu  # noqa: WPS433

        cls.mvu = mvu

    def test_mounts_importable_module(self):
        patterns = []

        def _importer(name):
            if name != "openedx_video_analytics.urls":
                raise ImportError(name)
            return object()

        self.mvu._mount_if_importable(
            patterns,
            "openedx_video_analytics.urls",
            "api/video/v1/",
            importer=_importer,
            include_func=lambda module_name: {"include": module_name},
            path_func=lambda route, view: {"route": route, "view": view},
        )

        self.assertEqual(
            patterns,
            [
                {"route": "api/video/v1/", "view": {"include": "openedx_video_analytics.urls"}},
            ],
        )

    def test_skips_missing_module(self):
        patterns = []

        self.mvu._mount_if_importable(
            patterns,
            "openedx_video_pipeline.urls",
            "api/video-pipeline/",
            importer=lambda _name: (_ for _ in ()).throw(ImportError("missing")),
            include_func=lambda module_name: {"include": module_name},
            path_func=lambda route, view: {"route": route, "view": view},
        )

        self.assertEqual(patterns, [])


if __name__ == "__main__":
    unittest.main()
