"""
Setup configuration for openedx_push_notifications Django app.
"""

from setuptools import setup, find_packages

setup(
    name='openedx_push_notifications',
    version='1.0.0',
    description='Push notification dispatch via FCM for Open edX',
    author='Mereka Team',
    author_email='tech@mereka.io',
    packages=find_packages(),
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
