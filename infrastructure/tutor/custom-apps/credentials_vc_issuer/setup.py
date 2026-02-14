"""
Setup configuration for credentials_vc_issuer Django app.
"""

from setuptools import setup, find_packages

setup(
    name='credentials_vc_issuer',
    version='1.0.0',
    description='Verifiable Credentials issuer identity and DID document endpoint for Open edX Credentials',
    author='Mereka Team',
    author_email='tech@mereka.io',
    packages=find_packages(),
    install_requires=[
        'Django>=3.2',
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
