"""
Setup configuration for openedx_push_notifications Django app.
"""

from setuptools import find_packages, setup

_SUBPACKAGES = find_packages(where=".")
_PACKAGES = [
    "openedx_push_notifications",
    *[f"openedx_push_notifications.{name}" for name in _SUBPACKAGES],
]

setup(
    name='openedx_push_notifications',
    version='1.0.0',
    description='Push notification dispatch via FCM for Open edX',
    author='Mereka Team',
    author_email='tech@mereka.io',
    packages=_PACKAGES,
    package_dir={'openedx_push_notifications': '.'},
    install_requires=[
        'Django>=3.2',
        'djangorestframework>=3.14',
        'edx-ace>=1.3.0',
        'google-auth>=2.0',
        'requests>=2.28',
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
