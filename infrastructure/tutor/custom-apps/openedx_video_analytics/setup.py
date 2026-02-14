from setuptools import setup, find_packages

setup(
    name='openedx-video-analytics',
    version='1.0.0',
    description='Video playback analytics for Open edX',
    author='Mereka Academy',
    author_email='platform@mereka.io',
    url='https://github.com/Biji-Biji-Initiative/mereka-lms',
    packages=find_packages(),
    install_requires=[
        'Django>=3.2',
        'djangorestframework>=3.14',
        'celery>=5.2.0',
    ],
    classifiers=[
        'Development Status :: 4 - Beta',
        'Framework :: Django',
        'Intended Audience :: Developers',
        'License :: OSI Approved :: AGPL-3.0',
        'Programming Language :: Python :: 3.10',
        'Programming Language :: Python :: 3.11',
    ],
    python_requires='>=3.10',
)
