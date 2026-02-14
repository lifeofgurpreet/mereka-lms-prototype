"""Setup for openedx_content_libraries Django app."""
from setuptools import setup, find_packages

setup(
    name='openedx_content_libraries',
    version='1.0.0',
    description='Content Libraries v2 extensions for Mereka Academy',
    author='Mereka Team',
    author_email='tech@mereka.io',
    packages=find_packages(),
    install_requires=[
        'Django>=3.2',
        'djangorestframework>=3.14',
    ],
    python_requires='>=3.11',
)
