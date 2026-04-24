"""Setup script for openedx_mobile_api package."""

from setuptools import find_packages, setup

_SUBPACKAGES = find_packages(where=".")
_PACKAGES = [
    "openedx_mobile_api",
    *[f"openedx_mobile_api.{name}" for name in _SUBPACKAGES],
]

setup(
    name="openedx-mobile-api",
    version="1.0.0",
    description="Mobile Backend API for Open edX",
    author="Mereka Academy",
    author_email="tech@mereka.io",
    packages=_PACKAGES,
    package_dir={'openedx_mobile_api': '.'},
    install_requires=[
        "Django>=3.2",
        "djangorestframework>=3.12",
    ],
    include_package_data=True,
    classifiers=[
        "Development Status :: 4 - Beta",
        "Framework :: Django",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3.8",
    ],
)
