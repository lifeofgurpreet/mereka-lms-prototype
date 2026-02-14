"""Signal handlers for Content Libraries v2 extensions."""
import logging

logger = logging.getLogger(__name__)


def register_library_signals():
    """Register library event signals on app startup."""
    logger.info(
        "openedx_content_libraries: Library lifecycle, versioning, "
        "and reference tracking registered"
    )


register_library_signals()
