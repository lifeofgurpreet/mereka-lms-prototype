"""Setup for XQueue Graders Django App"""
from setuptools import find_packages, setup

_SUBPACKAGES = find_packages(where=".")
_PACKAGES = [
    "openedx_xqueue_graders",
    *[f"openedx_xqueue_graders.{name}" for name in _SUBPACKAGES],
]

setup(
    name='openedx-xqueue-graders',
    version='1.0.0',
    description='XQueue Graders - Python Code Sandbox for Open edX',
    author='Mereka Academy',
    author_email='tech@mereka.io',
    packages=_PACKAGES,
    package_dir={'openedx_xqueue_graders': '.'},
    include_package_data=True,
    install_requires=[
        'Django>=3.2',
        'prometheus-client>=0.12.0',
        'numpy>=1.20.0',  # For percentile calculations
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
