"""Cython build file"""
from distutils.core import setup, Extension
from Cython.Build import cythonize
import os

if __name__ == "__main__":
    cythonExt = []
    for root, dirs, files in os.walk(os.getcwd()):
        for file in files:
            if file.endswith(".pyx") and ".pyenv" not in root and "venv" not in root:
                filePath = os.path.relpath(os.path.join(root, file))
                cythonExt.append(Extension(filePath.replace("\\", ".").replace("/", ".")[:-4], [filePath]))

    setup(
        name="lets pyx modules",
        ext_modules=cythonize(cythonExt, nthreads=4, compiler_directives={"language_level": 3}),
    )
