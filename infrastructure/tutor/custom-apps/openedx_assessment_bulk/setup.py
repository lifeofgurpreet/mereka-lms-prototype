"""Setup for Assessment Bulk Operations Django App"""
from setuptools import find_packages, setup

_SUBPACKAGES = find_packages(where=".")
_PACKAGES = [
    "openedx_assessment_bulk",
    *[f"openedx_assessment_bulk.{name}" for name in _SUBPACKAGES],
]

setup(
    name='openedx-assessment-bulk',
    version='1.0.0',
    description='Assessment Bulk Operations - Regrade, Export, Import, Security for Open edX',
    author='Mereka Academy',
    author_email='tech@mereka.io',
    packages=_PACKAGES,
    package_dir={'openedx_assessment_bulk': '.'},
    include_package_data=True,
    install_requires=[
        'Django>=3.2',
        'edx-opaque-keys>=2.0.0',
    ],
    classifiers=[
        'Development Status :: 4 - Beta',
        'Framework :: Django',
        'Framework :: Django :: 3.2',
        'Intended Audience :: Developers',
        'License :: OSI Approved :: MIT License',
        'Operating System :: OS Independent',
        'Programming Language :: Python :: 3',
        'Programming Language :: Python :: 3.8',
        'Programming Language :: Python :: 3.10',
    ],
    python_requires='>=3.8',
)
