from setuptools import find_packages, setup

_SUBPACKAGES = find_packages(where=".")
_PACKAGES = [
    "openedx_video_pipeline",
    *[f"openedx_video_pipeline.{name}" for name in _SUBPACKAGES],
]

setup(
    name='openedx-video-pipeline',
    version='1.0.0',
    description='MCT video migration validation for Open edX',
    author='Mereka Academy',
    author_email='platform@mereka.io',
    url='https://github.com/Biji-Biji-Initiative/mereka-lms',
    packages=_PACKAGES,
    package_dir={'openedx_video_pipeline': '.'},
    install_requires=[
        'Django>=3.2',
        'djangorestframework>=3.14',
        'requests>=2.28.0',
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
