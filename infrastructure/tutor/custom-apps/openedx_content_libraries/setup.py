"""Setup for openedx_content_libraries Django app."""
from setuptools import find_packages, setup

_SUBPACKAGES = find_packages(where=".")
_PACKAGES = [
    "openedx_content_libraries",
    *[f"openedx_content_libraries.{name}" for name in _SUBPACKAGES],
]

setup(
    name='openedx_content_libraries',
    version='1.0.0',
    description='Content Libraries v2 extensions for Mereka Academy',
    author='Mereka Team',
    author_email='tech@mereka.io',
    packages=_PACKAGES,
    package_dir={'openedx_content_libraries': '.'},
    install_requires=[
        'Django>=3.2',
        'djangorestframework>=3.14',
    ],
    python_requires='>=3.11',
)
