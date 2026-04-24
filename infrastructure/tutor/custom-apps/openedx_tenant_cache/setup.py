"""
Setup configuration for openedx_tenant_cache Django app.
"""

from setuptools import find_packages, setup

_SUBPACKAGES = find_packages(where=".")
_PACKAGES = [
    "openedx_tenant_cache",
    *[f"openedx_tenant_cache.{name}" for name in _SUBPACKAGES],
]

setup(
    name='openedx_tenant_cache',
    version='1.0.0',
    description='Multi-tenant cache namespacing and foundation for Open edX',
    author='Mereka Team',
    author_email='tech@mereka.io',
    packages=_PACKAGES,
    package_dir={'openedx_tenant_cache': '.'},
    install_requires=[
        'Django>=3.2',
        'djangorestframework>=3.14',
        'prometheus_client>=0.17',
    ],
    classifiers=[
        'Development Status :: 4 - Beta',
        'Framework :: Django',
        'Intended Audience :: Developers',
        'License :: OSI Approved :: MIT License',
        'Operating System :: OS Independent',
        'Programming Language :: Python :: 3',
        'Programming Language :: Python :: 3.11',
    ],
    python_requires='>=3.11',
)
