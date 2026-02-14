"""Setup script for openedx_video_protection Django app"""
from setuptools import find_packages, setup

setup(
    name='openedx-video-protection',
    version='1.0.0',
    description='Video Content Protection for Open edX (Mux signed playback URLs)',
    author='Mereka Academy',
    author_email='platform@mereka.io',
    url='https://github.com/Biji-Biji-Initiative/mereka-lms',
    packages=find_packages(),
    include_package_data=True,
    install_requires=[
        'Django>=3.2',
        'djangorestframework>=3.14',
        'PyJWT>=2.8.0',
        'cryptography>=41.0.0',  # For RSA key handling
        'opaque-keys>=2.0.0',
    ],
    classifiers=[
        'Development Status :: 4 - Beta',
        'Framework :: Django',
        'Framework :: Django :: 3.2',
        'Intended Audience :: Developers',
        'License :: OSI Approved :: MIT License',
        'Operating System :: OS Independent',
        'Programming Language :: Python :: 3',
        'Programming Language :: Python :: 3.10',
        'Programming Language :: Python :: 3.11',
    ],
    python_requires='>=3.10',
)
