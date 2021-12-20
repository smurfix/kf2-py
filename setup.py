from setuptools import setup
from Cython.Build import cythonize
from distutils.extension import Extension
import sys

ext = Extension(
            "kf2",
            [
                "kf2.pyx",
            ],
            extra_compile_args=[
                "-DKF_EMBED",
                "-DKF_SIMD=4",
            ],
            language="c++",
            include_dirs=[
                "../embed",
                "../common",
                "../fraktal_sft",
                "../glad/include",
                *sys.path,
                "/usr/include/pixman-1",
                "/usr/include/OpenEXR",
                "/usr/include/OpenEXR",
            ],
            libraries=[
                "kf2-embed",
                'gmp', 'mpfr', 'mpc'
            ],
            library_dirs=[
                "..",
            ],
        )

setup(
    ext_modules=cythonize(
        ext,
        language_level=3,
    ),
)
