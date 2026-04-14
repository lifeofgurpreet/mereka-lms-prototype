"""Setup for Advanced XBlocks Django App"""
from setuptools import find_packages, setup

_SUBPACKAGES = find_packages(where=".")
_PACKAGES = [
    "openedx_advanced_xblocks",
    *[f"openedx_advanced_xblocks.{name}" for name in _SUBPACKAGES],
]

setup(
    name='openedx-advanced-xblocks',
    version='1.0.0',
    description='Advanced XBlocks - Drag-Drop, Math Input, Randomization for Open edX',
    author='Mereka Academy',
    author_email='tech@mereka.io',
    packages=_PACKAGES,
    package_dir={'openedx_advanced_xblocks': '.'},
    include_package_data=True,
    install_requires=[
        'Django>=3.2',
        'xblock>=1.6.0',
        'edx-opaque-keys>=2.0.0',
    ],
    entry_points={
        'xblock.v1': [
            'drag_drop_v2 = openedx_advanced_xblocks.xblocks:DragDropV2XBlock',
            'math_input = openedx_advanced_xblocks.xblocks:MathInputXBlock',
            'randomized_pool = openedx_advanced_xblocks.xblocks:RandomizedPoolXBlock',
        ]
    },
    classifiers=[
        'Development Status :: 4 - Beta',
        'Framework :: Django',
        'Framework :: Django :: 3.2',
        'Intended Audience :: Developers',
        'License :: OSI Approved :: MIT License',
        'Operating System :: OS Independent',
        'Programming Language :: Python :: 3',
        'Programming Language :: Python :: 3.8',
        'Programming Language :: Python :: 3.10',
    ],
    python_requires='>=3.8',
)
