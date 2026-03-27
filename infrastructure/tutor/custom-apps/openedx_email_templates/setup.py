"""
Setup configuration for openedx_email_templates Django app.
"""

from setuptools import setup, find_packages

setup(
    name='openedx_email_templates',
    version='1.0.0',
    description='Email templates and bulk campaign engine for Open edX',
    author='Mereka Team',
    author_email='tech@mereka.io',
    packages=find_packages(),
    install_requires=[
        'Django>=3.2',
        'djangorestframework>=3.14',
        'edx-ace>=1.3.0',
        'celery>=5.2',
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
