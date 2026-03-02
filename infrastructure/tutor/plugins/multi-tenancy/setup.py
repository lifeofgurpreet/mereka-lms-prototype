"""
Setup configuration for mereka_tenancy Django app.
"""

from setuptools import setup

setup(
    name='mereka_tenancy',
    version='1.0.0',
    description='Multi-tenancy extensions for Open edX EnterpriseCustomer',
    author='Mereka Team',
    author_email='tech@mereka.io',
    packages=['mereka_tenancy', 'mereka_tenancy.management', 'mereka_tenancy.migrations'],
    package_dir={'mereka_tenancy': '.'},
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
