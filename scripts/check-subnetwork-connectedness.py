# SPDX-FileCopyrightText: 2025 Alexandru Fikl <alexfikl@gmail.com>
# SPDX-License-Identifier: MIT

from __future__ import annotations

import logging
import pathlib

import numpy as np
import rich.logging

log = logging.getLogger(pathlib.Path(__file__).stem)
log.setLevel(logging.ERROR)
log.addHandler(rich.logging.RichHandler())

SCRIPT_PATH = pathlib.Path(__file__)
SCRIPT_LONG_HELP = f"""\
This script takes a MATLAB `.mat` file containing some matrices and checks the
connectedness of the resulting graphs.

Example:

    > {SCRIPT_PATH.name} --variable-name matrices data.mat
"""


def check_connected(
    filename: pathlib.Path,
    *,
    mat_variable_names: list[str] | None = None,
    clip: tuple[float, float] | None = None,
) -> int:
    # {{{ load

    if not filename.exists():
        log.error("File does not exist: '%s'.", filename)
        return 1

    if mat_variable_names is None:
        mat_variable_names = []

    if clip is None:
        clip = (0.0, np.inf)

    from scipy.io import loadmat

    contents = loadmat(filename)

    ret = 0
    matrices = []
    for name in mat_variable_names:
        mat = contents[name]
        if not isinstance(mat, np.ndarray):
            ret = 1
            log.error("Object '%s' is not an ndarray: '%s'", name, type(mat).__name__)
            continue

        if mat.ndim != 3:
            ret = 1
            log.error("Object '%s' has unsupported shape: %s", name, mat.shape)
            continue

        matrices.extend(mat[..., i] for i in range(mat.shape[-1]))
        log.info("Read a matrix of size '%s' from '%s'.", mat.shape, name)

    # }}}

    # {{{ check

    import networkx as nx

    for i, mat in enumerate(matrices):
        cmat = np.clip(mat, a_min=clip[0], a_max=clip[1])

        graph = nx.from_numpy_array(mat)
        nnodes, nedges = graph.number_of_nodes(), graph.number_of_edges()
        log.info(
            "Exhibit %2d: nnodes %5d edges %5d connected %s",
            i,
            nnodes,
            nedges,
            nx.is_connected(graph),
        )

        graph = nx.from_numpy_array(cmat)
        nnodes, nedges = graph.number_of_nodes(), graph.number_of_edges()
        log.info(
            "          : nnodes %5d edges %5d connected %s",
            nnodes,
            nedges,
            nx.is_connected(graph),
        )

    # }}}

    return ret


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
        "-n",
        "--variable-name",
        action="append",
        help="Name of the variable containing matrices in the .mat file",
    )
    parser.add_argument(
        "--clip",
        type=float,
        nargs=2,
        default=(0.0, np.inf),
        help="Clip matrix entries to the maximum and minimum values given",
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
        check_connected(
            args.filename,
            mat_variable_names=args.variable_name,
            clip=args.clip,
        )
    )
