"""
XBlock implementations for advanced assessment types

Provides drag-and-drop v2, math input, and randomized question pools.

Imports are deferred because the XBlock plugin loader runs before
INSTALLED_APPS is finalized, and our models.py defines Django models
that require the app to be registered.
"""


def __getattr__(name):
    """Lazy import XBlock classes to avoid early model registration."""
    if name == 'DragDropV2XBlock':
        from .drag_drop_v2 import DragDropV2XBlock
        return DragDropV2XBlock
    if name == 'MathInputXBlock':
        from .math_input import MathInputXBlock
        return MathInputXBlock
    if name == 'RandomizedPoolXBlock':
        from .randomized_pool import RandomizedPoolXBlock
        return RandomizedPoolXBlock
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")


__all__ = [
    'DragDropV2XBlock',
    'MathInputXBlock',
    'RandomizedPoolXBlock',
]
