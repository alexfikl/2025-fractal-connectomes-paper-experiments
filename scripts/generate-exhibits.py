# SPDX-FileCopyrightText: 2024 Alexandru Fikl <alexfikl@gmail.com>
# SPDX-License-Identifier: MIT

from __future__ import annotations

import json
import logging
import pathlib
from typing import Any

import numpy as np
import numpy.linalg as la
import rich.logging

log = logging.getLogger(pathlib.Path(__file__).stem)
log.setLevel(logging.ERROR)
log.addHandler(rich.logging.RichHandler())

SCRIPT_PATH = pathlib.Path(__file__)
SCRIPT_LONG_HELP = f"""\
This script generates a collection of JSON files that can be used with the main
`netbrot` executable to define the fractal that will be rendered. The JSON
files have a very specific format (so that they can be loaded by `serde`), so
be careful when playing with them manually!

The script takes a MATLAB `.mat` file containing some matrices and converts them.
If the given variable is a 3-dimensional tensor, the first dimension is
considered an index for multiple matrices. Like that, a matrix of size
`(7, 32, 32)` will generate 7 different JSON files.

The bounding box for rendering can be specified using the `--xlim` and `--ylim`
parameters. The resulting JSON files has the following fields
```JSON
{{
    "mat": [[[mij.real, mij.imag], ...], nx, ny],
    "escape_radius": 1.0,
    "upper_left": [ux, uy],
    "lower_right": [lx, ly],
}}
```

Example:

    > {SCRIPT_PATH.name} --variable-name matrices data.mat
"""

# {{{ utils

Array = np.ndarray[Any, np.dtype[Any]]

DEFAULT_UPPER_LEFT = (-10.25, 4.25)
DEFAULT_LOWER_RIGHT = (7.5, -7.5)


def serde_matrix_format(mat: Array) -> list[Any]:
    result = [[float(item), 0.0] for row in mat.T for item in row]
    return [result, *mat.shape]


def estimate_escape_radius(mat: Array) -> float:
    n = mat.shape[0]
    sigma = np.linalg.svdvals(mat)

    return 2.0 * np.sqrt(n) / np.min(sigma) ** 2


def dump(
    outfile: pathlib.Path,
    mat: Array,
    upper_left: tuple[float, float] = DEFAULT_UPPER_LEFT,
    lower_right: tuple[float, float] = DEFAULT_LOWER_RIGHT,
    *,
    max_escape_radius: float | None = None,
    overwrite: bool = False,
) -> int:
    if not overwrite and outfile.exists():
        log.error("Output file exists (use --overwrite): '%s'.", outfile)
        return 1

    if max_escape_radius is None:
        max_escape_radius = np.inf

    with open(outfile, "w", encoding="utf-8") as outf:
        escape_radius = estimate_escape_radius(mat)
        exhibit_escape_radius = min(escape_radius, max_escape_radius)
        log.info(
            "Dumping exhibit '%s': shape %s (cond %.3e) escape radius %g (real %g)",
            outfile.stem,
            mat.shape,
            np.linalg.cond(mat),
            exhibit_escape_radius,
            escape_radius,
        )

        json.dump(
            {
                "mat": serde_matrix_format(mat),
                "escape_radius": exhibit_escape_radius,
                "upper_left": upper_left,
                "lower_right": lower_right,
            },
            outf,
            indent=2,
            sort_keys=False,
        )

    log.info("Saved matrix in '%s'.", outfile)
    return 0


# }}}


# {{{ convert MATLAB file


def convert_matlab(
    filename: pathlib.Path,
    outfile: pathlib.Path | None = None,
    *,
    mat_variable_names: list[str] | None = None,
    upper_left: tuple[float, float] | None = None,
    lower_right: tuple[float, float] | None = None,
    max_escape_radius: float | None = None,
    clip: tuple[float, float] | None = None,
    transpose: bool = False,
    normalize: str | None = None,
    absolute: bool = False,
    include_average: bool = False,
    overwrite: bool = False,
) -> int:
    # {{{ sanitize inputs

    if not filename.exists():
        log.error("File does not exist: '%s'.", filename)
        return 1

    if outfile is None:
        outfile = filename.with_suffix(".json")

    if mat_variable_names is None:
        mat_variable_names = []

    if upper_left is None:
        upper_left = DEFAULT_UPPER_LEFT

    if lower_right is None:
        lower_right = DEFAULT_LOWER_RIGHT

    if upper_left[0] > lower_right[0]:
        log.error("Invalid bounds: xmin %s xmax %s", upper_left[0], lower_right[0])
        return 1

    if upper_left[1] < lower_right[1]:
        log.error("Invalid bounds: ymin %s ymax %s", upper_left[1], lower_right[1])
        return 1

    if max_escape_radius <= 0.0:
        log.error("Negative maximum escape radius: %s", max_escape_radius)
        return 1

    # }}}

    # {{{ read matrices

    from scipy.io import loadmat

    result = loadmat(filename)

    ret = 0
    matrices = []
    for name in mat_variable_names:
        mat = result[name]
        if not isinstance(mat, np.ndarray):
            ret = 1
            log.error("Object '%s' is not an ndarray: '%s'", name, type(mat).__name__)
            continue

        new_matrices = []
        if mat.ndim == 2:
            if transpose:
                mat = mat.T

            new_matrices.append(mat)
        elif mat.ndim == 3:
            if transpose:
                new_matrices.extend(mat[..., i] for i in range(mat.shape[-1]))
            else:
                new_matrices.extend(mat[i] for i in range(mat.shape[0]))
        else:
            ret = 1
            log.error("Object '%s' has unsupported shape: %s", name, mat.shape)
            continue

        matrices.extend(new_matrices)
        log.info("Read a matrix of size '%s' from '%s'.", mat.shape, name)

    if not matrices:
        log.warning("Failed to read any matrices from '%s'.", filename)
        return ret

    # }}}

    # {{{ write matrices

    mat_avg = 0
    width = len(str(len(matrices)))
    for i, mat in enumerate(matrices):
        mat_i = mat

        if clip is not None:
            mat_i = np.clip(mat_i, a_min=clip[0], a_max=clip[1])

        if absolute:
            mat_i = np.abs(mat_i)

        if normalize is not None:
            if normalize == "1":
                mat_i /= la.norm(mat_i, ord=1)
            elif normalize == "2":
                mat_i /= la.norm(mat_i, ord=2)
            elif normalize == "inf":
                mat_i /= la.norm(mat_i, ord=np.inf)
            elif normalize == "fro":
                mat_i /= la.norm(mat_i, ord="fro")
            elif normalize == "nuc":
                mat_i /= la.norm(mat_i, ord="nuc")
            elif normalize == "max":
                mat_i /= np.max(np.abs(mat_i))
            else:
                raise ValueError(f"Unknown norm type: '{normalize}'")

        mat_avg += mat_i
        outfile_i = outfile.with_stem(f"{outfile.stem}-{i:0{width}}")
        ret |= dump(
            outfile_i,
            mat_i,
            upper_left,
            lower_right,
            max_escape_radius=max_escape_radius,
            overwrite=overwrite,
        )

    if include_average:
        outfile_i = outfile.with_stem(f"{outfile.stem}-avg")
        ret |= dump(
            outfile_i,
            mat_avg / len(matrices),
            upper_left,
            lower_right,
            max_escape_radius=max_escape_radius,
            overwrite=overwrite,
        )

    # }}}

    return ret


# }}}


if __name__ == "__main__":
    import argparse

    class HelpFormatter(
        argparse.ArgumentDefaultsHelpFormatter,
        argparse.RawDescriptionHelpFormatter,
    ):
        pass

    parser = argparse.ArgumentParser(
        formatter_class=HelpFormatter,
        description=SCRIPT_LONG_HELP,
    )
    parser.add_argument("filename", type=pathlib.Path)
    parser.add_argument(
        "-o",
        "--outfile",
        type=pathlib.Path,
        default=None,
        help="Basename for output files (named '{basename}-XX')",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Overwrite existing files",
    )
    parser.add_argument(
        "-n",
        "--variable-name",
        action="append",
        help="Name of the variable containing matrices in the .mat file",
    )
    parser.add_argument(
        "-t",
        "--transpose",
        action="store_true",
        help="Transpose the matrix that is read from the .mat file",
    )
    parser.add_argument(
        "-z",
        "--normalize",
        choices=("1", "2", "inf", "fro", "nuc", "max"),
        default=None,
        help="Normalize the matrices by their norm",
    )
    parser.add_argument(
        "-a",
        "--abs",
        action="store_true",
        help="Take the absolute value of all matrix entries",
    )
    parser.add_argument(
        "--clip",
        type=float,
        nargs=2,
        default=None,
        help="Clip matrix entries to the maximum and minimum values given",
    )
    parser.add_argument(
        "--include-average",
        action="store_true",
        help="Also create an exhibit with the average of the matrices",
    )
    parser.add_argument(
        "-x",
        "--xlim",
        type=float,
        nargs=2,
        default=(DEFAULT_UPPER_LEFT[0], DEFAULT_LOWER_RIGHT[0]),
        help="Rendering bounds (in physical space) for the x coordinate",
    )
    parser.add_argument(
        "-y",
        "--ylim",
        type=float,
        nargs=2,
        default=(DEFAULT_LOWER_RIGHT[1], DEFAULT_UPPER_LEFT[1]),
        help="Rendering bounds (in physical space) for the y coordinate",
    )
    parser.add_argument(
        "-r",
        "--escape-radius",
        default=None,
        type=float,
        help="Maximum escape radius",
    )
    parser.add_argument(
        "-q",
        "--quiet",
        action="store_true",
        help="Only show error messages",
    )
    args = parser.parse_args()

    if not args.quiet:
        log.setLevel(logging.INFO)

    raise SystemExit(
        convert_matlab(
            args.filename,
            mat_variable_names=args.variable_name,
            upper_left=(args.xlim[0], args.ylim[1]),
            lower_right=(args.xlim[1], args.ylim[0]),
            max_escape_radius=args.escape_radius,
            outfile=args.outfile,
            transpose=args.transpose,
            normalize=args.normalize,
            absolute=args.abs,
            clip=args.clip,
            include_average=args.include_average,
            overwrite=args.overwrite,
        )
    )
