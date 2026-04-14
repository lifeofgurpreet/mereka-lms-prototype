"""
Setup configuration for mfe_oauth_fix Django app.
"""

from setuptools import find_packages, setup

_SUBPACKAGES = find_packages(where=".")
_PACKAGES = [
    "mfe_oauth_fix",
    *[f"mfe_oauth_fix.{name}" for name in _SUBPACKAGES],
]

setup(
    name='mfe_oauth_fix',
    version='1.0.0',
    description='Fix for MFE OAuth provider visibility in Open edX',
    author='Mereka Team',
    author_email='tech@mereka.io',
    packages=_PACKAGES,
    package_dir={'mfe_oauth_fix': '.'},
    install_requires=[],
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
