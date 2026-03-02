"""
Setup configuration for mereka_email_suppression Django app.
"""

from setuptools import find_packages, setup

setup(
    name='mereka_email_suppression',
    version='1.0.0',
    description='Email bounce and complaint suppression for AWS SES',
    author='Mereka Team',
    author_email='tech@mereka.io',
    packages=find_packages(),
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
