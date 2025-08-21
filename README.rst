Introduction
------------

.. |badge-license| image:: https://img.shields.io/badge/License-MIT-blue.svg
    :target: https://spdx.org/licenses/MIT.html
    :alt: MIT License

|badge-license|

This repository contains some scripts that were used to generate the equi-M
sets from the paper. The versions of all the dependencies are fixed and should
allow for reproducible results.

We use the [just](https://github.com/casey/just) command runner to help automate
the equi-M set generation.

Install
-------

The code uses Python for some pre and post-processing tasks and the
`netbrot <https://github.com/alexfikl/netbrot>`__ project to actually generate the
equi-M sets. The dependencies are pinned in the acompanying ``requirements.txt`` file.

To install all the necessary dependencies run

.. code:: bash

    just install

This will create a virtual environment at ``.venv`` in the current directory with
all the pinned python dependencies and the ``netbrot`` application installed in
``.venv/bin``. The paths may differ slightly on Windows.

Equi-M Set Generation
---------------------

To generate e.g. the equi-M sets for the Structural connectomes (Figure A1 in the
paper), you can run

.. code:: bash

    just generate_structural

This will create a bunch of JSON files in a new directory. These JSON files are
then given to ``netbrot`` one by one to generate the equi-M sets. Since the equi-M
sets are generated at quite a high resolution, this may take a while. In our runs,
about 5 minutes per connectome (for a total of 5 min x 48 ~ 4 hours).

To generate all the equi-M sets run

.. code:: bash

   just generate

Fourier Parametrization
-----------------------

The Fourier parametrization of the equi-M sets can be obtained with the
``scripts/fourier-parametrize.py`` script that is part of the ``netbrot`` package.
For example, using the images that were generated using ``just generate``, we can
run

.. code:: bash

   python scripts/fourier-parametrize.py \
        --overwrite \
        --outfile exhibit_structural_fourier.mat \
        exhibit_structural/exhibit-*-1200x512-*.png

This will output a file called ``exhibit_structural_fourier.mat`` that contains
the Fourier modes and other quantities computed using the Fourier parametrization
(centroids, area, perimeters, etc.). These files are also automatically generated
when running ``just generate``.
