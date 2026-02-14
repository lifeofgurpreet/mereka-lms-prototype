"""Setup script for openedx_kajabi_sso package."""

from setuptools import setup, find_packages

setup(
    name="openedx-kajabi-sso",
    version="1.0.0",
    description="Kajabi SSO/OAuth Integration for Open edX",
    author="Mereka Academy",
    author_email="tech@mereka.io",
    packages=find_packages(),
    install_requires=[
        "Django>=3.2",
        "social-auth-app-django>=5.0.0",
        "social-auth-core>=4.0.0",
    ],
    classifiers=[
        "Development Status :: 4 - Beta",
        "Framework :: Django",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3.8",
    ],
)
