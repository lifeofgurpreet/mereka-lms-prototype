"""
Setup configuration for openedx_prometheus Django app.
"""

from setuptools import setup, find_packages

setup(
    name='openedx_prometheus',
    version='1.0.0',
    description='Prometheus metrics integration for Open edX',
    author='Mereka Team',
    author_email='tech@mereka.io',
    packages=find_packages(),
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
