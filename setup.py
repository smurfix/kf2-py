from setuptools import setup
from Cython.Build import cythonize
from distutils.extension import Extension

ext = Extension(
            "kf2", ["kf2.pyx",
                "kf-fraktal_sft.cpp",
                "kf-scale_bitmap.cpp",
            ],
            extra_compile_args=[
                "-DKF_EMBED",
                "-DKF_SIMD=4",
            ],
            language="c++",
            include_dirs=[
                "./inc",
                "../fraktal_sft",
                "../glad/include",
                "/usr/include/pixman-1",
                "/usr/include/OpenEXR",
            ],
            libraries=[],
            library_dirs=["../baru/"],
        )

setup(
    ext_modules=cythonize(
        ext,
        language_level=3,
    ),
)
