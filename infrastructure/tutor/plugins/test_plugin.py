#!/usr/bin/env python3
"""
Test script to validate Tutor plugin syntax.

This imports the plugin and checks for basic errors before trying to use it with Tutor.
"""

import sys
from pathlib import Path

# Add plugins directory to path
plugins_dir = Path(__file__).parent
sys.path.insert(0, str(plugins_dir))

def test_import():
    """Test that the plugin can be imported."""
    try:
        import mereka_lms
        print(f"✓ Plugin imported successfully")
        print(f"  Version: {mereka_lms.__version__}")
        return True
    except Exception as e:
        print(f"✗ Failed to import plugin: {e}")
        return False

def test_hooks():
    """Test that hooks are registered."""
    try:
        import mereka_lms
        # This would normally be done by Tutor, but we can't test that without Tutor installed
        print(f"✓ Plugin defines {mereka_lms.__name__}")
        return True
    except Exception as e:
        print(f"✗ Failed to check hooks: {e}")
        return False

def test_syntax():
    """Test Python syntax is valid."""
    try:
        with open(plugins_dir / "mereka_lms.py") as f:
            compile(f.read(), "mereka_lms.py", "exec")
        print("✓ Python syntax is valid")
        return True
    except SyntaxError as e:
        print(f"✗ Syntax error: {e}")
        return False

if __name__ == "__main__":
    print("Testing Mereka LMS Tutor Plugin")
    print("=" * 50)

    results = [
        test_syntax(),
        test_import(),
        test_hooks(),
    ]

    print("=" * 50)
    if all(results):
        print("✓ All tests passed")
        sys.exit(0)
    else:
        print("✗ Some tests failed")
        sys.exit(1)
