PYTHON_VENV := '.venv'
PYTHON := 'python -X dev'
NETBROT := PYTHON_VENV + '/bin/netbrot'
NETBROT_RESOLUTION := '1200'
NETBROT_MAXIT := '512'
NETBROT_MAX_ESCAPE_RADIUS := '100.0'

_default:
    @just --list

# {{{ formatting

alias fmt: format

[doc('Run all formatting scripts over the source code')]
format: justfmt isort black

[doc('Run just --fmt over the justfile')]
justfmt:
    just --unstable --fmt
    @echo -e "\e[1;32mjust --fmt clean!\e[0m"

[doc('Run ruff isort fixes over the source code')]
isort:
    ruff check --fix --select=I scripts
    ruff check --fix --select=RUF022 scripts
    @echo -e "\e[1;32mruff isort clean!\e[0m"

[doc('Run ruff format over the source code')]
black:
    ruff format scripts
    @echo -e "\e[1;32mruff format clean!\e[0m"

# }}}
# {{{ linting

[doc('Run all linting checks over the source code')]
lint: typos ruff

[doc('Run typos over the source code and documentation')]
typos:
    typos --sort --format=brief scripts
    @echo -e "\e[1;32mtypos clean!\e[0m"

[doc('Run ruff checks over the source code')]
ruff:
    ruff check --quiet --output-format=pylint scripts
    @echo -e "\e[1;32mruff clean!\e[0m"

# }}}
# {{{ install

[doc("Pin requirements")]
pin:
    uv pip compile \
        --upgrade --universal --python-version "3.10" \
        -o requirements.txt pyproject.toml

[doc("Create a virtual environment and install the necessary dependencies")]
install: create_venv install_python install_netbrot

[doc("Create a local virtual environment")]
create_venv:
    uv venv --clear {{ PYTHON_VENV }}

[doc("Install Python dependencies")]
install_python:
    uv pip install -r requirements.txt --python {{ PYTHON_VENV }}

[doc("Install netbrot")]
install_netbrot:
    cargo install \
        --root {{ PYTHON_VENV }} \
        --git https://github.com/alexfikl/netbrot.git \
        --tag v2025.6.0 \
        --locked

# }}}
# {{{ exhibits

[doc('Regenerate all the exibits')]
exhibits: exhibit_structural exhibit_structural_random exhibit_rest exhibit_rest_positive exhibit_rest_negative exhibit_emotion exhibit_emotion_positive exhibit_emotion_negative

[doc('Convert structural data to JSON')]
exhibit_structural:
    @mkdir -p exhibit_structural
    {{ PYTHON }} scripts/generate-exhibits.py \
        --variable-name 'w' --transpose --normalize 'max' --include-average \
        --xlim '-1.0' '0.3' \
        --ylim '-0.65' '0.65' \
        --escape-radius {{ NETBROT_MAX_ESCAPE_RADIUS }} \
        --outfile exhibit_structural/exhibit.json --overwrite \
        data/Structural_Conn.mat

[doc('Convert random structural data to JSON')]
exhibit_structural_random:
    @mkdir -p exhibit_structural_random
    {{ PYTHON }} scripts/generate-exhibits.py \
        --variable-name 'C_rand' --transpose --normalize 'max' --include-average \
        --xlim '-1.1' '0.4' \
        --ylim '-0.75' '0.75' \
        --escape-radius {{ NETBROT_MAX_ESCAPE_RADIUS }} \
        --outfile exhibit_structural_random/exhibit.json --overwrite \
        data/Structural_Conn_Rand.mat

[doc('Convert rest data to JSON')]
exhibit_rest:
    @mkdir -p exhibit_rest
    {{ PYTHON }} scripts/generate-exhibits.py \
        --variable-name 'w' --transpose --include-average \
        --xlim '-0.03' '0.03' \
        --ylim '-0.03' '0.03' \
        --escape-radius {{ NETBROT_MAX_ESCAPE_RADIUS }} \
        --outfile exhibit_rest/exhibit.json --overwrite \
        data/Rest_LR_Task.mat

[doc('Convert rest data to JSON (positive only)')]
exhibit_rest_positive:
    @mkdir -p exhibit_rest_positive
    {{ PYTHON }} scripts/generate-exhibits.py \
        --variable-name 'w' --transpose --clip '0.0' 'inf' \
        --xlim '-0.01' '0.003' \
        --ylim '-0.0065' '0.0065' \
        --escape-radius {{ NETBROT_MAX_ESCAPE_RADIUS }} \
        --outfile exhibit_rest_positive/exhibit.json --overwrite \
        data/Rest_LR_Task.mat

[doc('Convert rest data to JSON (negative only)')]
exhibit_rest_negative:
    @mkdir -p exhibit_rest_negative
    {{ PYTHON }} scripts/generate-exhibits.py \
        --variable-name 'w' --transpose --clip '-inf' '0.0' \
        --xlim '-0.01' '0.003' \
        --ylim '-0.0065' '0.0065' \
        --escape-radius {{ NETBROT_MAX_ESCAPE_RADIUS }} \
        --outfile exhibit_rest_negative/exhibit.json --overwrite \
        data/Rest_LR_Task.mat

[doc('Convert all emotion data to JSON')]
exhibit_emotion:
    @mkdir -p exhibit_emotion
    {{ PYTHON }} scripts/generate-exhibits.py \
        --variable-name 'w' --transpose --include-average \
        --xlim '-0.03' '0.03' \
        --ylim '-0.03' '0.03' \
        --escape-radius {{ NETBROT_MAX_ESCAPE_RADIUS }} \
        --outfile exhibit_emotion/exhibit.json --overwrite \
        data/Emotion_LR_Task.mat

[doc('Convert all emotion data to JSON (positive only)')]
exhibit_emotion_positive:
    @mkdir -p exhibit_emotion_positive
    {{ PYTHON }} scripts/generate-exhibits.py \
        --variable-name 'w' --transpose --clip '0.0' 'inf' \
        --xlim '-0.01' '0.003' \
        --ylim '-0.0065' '0.0065' \
        --escape-radius {{ NETBROT_MAX_ESCAPE_RADIUS }} \
        --outfile exhibit_emotion_positive/exhibit.json --overwrite \
        data/Emotion_LR_Task.mat

[doc('Convert all emotion data to JSON (negative only)')]
exhibit_emotion_negative:
    @mkdir -p exhibit_emotion_negative
    {{ PYTHON }} scripts/generate-exhibits.py \
        --variable-name 'w' --transpose --clip '-inf' '0.0' \
        --xlim '-0.01' '0.003' \
        --ylim '-0.0065' '0.0065' \
        --escape-radius {{ NETBROT_MAX_ESCAPE_RADIUS }} \
        --outfile exhibit_emotion_negative/exhibit.json --overwrite \
        data/Emotion_LR_Task.mat

# }}}
# {{{ run

[doc("Run exhibits using netbrot")]
run directory:
    #!/usr/bin/env bash
    set -Eeuo pipefail

    function with_echo() {
        echo "+++" "$@"
        nice "$@"
    }

    suffix="{{ NETBROT_RESOLUTION }}x{{ NETBROT_MAXIT }}-$(date "+%Y%m%d")"
    for filename in {{ directory }}/*-avg.json; do
        with_echo {{ NETBROT }} \
            --render mandelbrot \
            --resolution {{ NETBROT_RESOLUTION }} \
            --maxit {{ NETBROT_MAXIT }} \
            --outfile "${filename%.json}-${suffix}.png" \
            "${filename}"
    done

[doc("Generate all equi-M sets")]
generate: gen_structural gen_structural_random gen_rest gen_rest_positive gen_rest_negative gen_emotion gen_emotion_positive gen_emotion_negative

[doc("Generate structural equi-M sets")]
gen_structural:
    just exhibit_structural
    just run exhibit_structural

[doc("Generate random structural equi-M sets")]
gen_structural_random:
    just exhibit_structural_random
    just run exhibit_structural_random

[doc("Generate rest equi-M sets")]
gen_rest:
    just exhibit_rest
    just run exhibit_rest

[doc("Generate positive rest equi-M sets")]
gen_rest_positive:
    just exhibit_rest_positive
    just run exhibit_rest_positive

[doc("Generate negative rest equi-M sets")]
gen_rest_negative:
    just exhibit_rest_negative
    just run exhibit_rest_negative

[doc("Generate emotion equi-M sets")]
gen_emotion:
    just exhibit_emotion
    just run exhibit_emotion

[doc("Generate positive emotion equi-M sets")]
gen_emotion_positive:
    just exhibit_emotion_positive
    just run exhibit_emotion_positive

[doc("Generate negative rest equi-M sets")]
gen_emotion_negative:
    just exhibit_emotion_negative
    just run exhibit_emotion_negative

# }}}
# {{{ clean

[doc('Remove all generated images')]
clean:
    find -type f -name '*.png' -delete

[doc('Remove all generated files')]
purge: clean
    find -type f -name '*.json' -delete
    rm -rf *.zip
    rm -rf *.npz
    rm -rf *.mat

# }}}
