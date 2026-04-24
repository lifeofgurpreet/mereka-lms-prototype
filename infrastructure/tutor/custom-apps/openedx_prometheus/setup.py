"""
Setup configuration for openedx_prometheus Django app.
"""

from setuptools import find_packages, setup

_SUBPACKAGES = find_packages(where=".")
_PACKAGES = [
    "openedx_prometheus",
    *[f"openedx_prometheus.{name}" for name in _SUBPACKAGES],
]

setup(
    name='openedx_prometheus',
    version='1.0.0',
    description='Prometheus metrics integration for Open edX',
    author='Mereka Team',
    author_email='tech@mereka.io',
    packages=_PACKAGES,
    package_dir={'openedx_prometheus': '.'},
    install_requires=[
        'django-prometheus>=2.3.1',
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
