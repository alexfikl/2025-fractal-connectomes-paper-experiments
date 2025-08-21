PYTHON := 'python -X dev'

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
lint: typos reuse ruff

[doc('Run typos over the source code and documentation')]
typos:
    typos --sort --format=brief scripts
    @echo -e "\e[1;32mtypos clean!\e[0m"

[doc('Check REUSE license compliance')]
reuse:
    {{ PYTHON }} -m reuse lint
    @echo -e "\e[1;32mREUSE compliant!\e[0m"

[doc('Run ruff checks over the source code')]
ruff:
    ruff check --quiet --output-format=pylint scripts
    @echo -e "\e[1;32mruff clean!\e[0m"

# }}}
# {{{ generate

[doc('Regenerate all the exibits')]
exhibits: gen_structural gen_structural_random gen_rest gen_rest_abs gen_rest_positive gen_rest_negative gen_emotion gen_emotion_abs gen_emotion_positive gen_emotion_negative

[doc('Convert structural data to JSON')]
gen_structural radius='100.0':
    @mkdir -p structural-conn
    {{ PYTHON }} scripts/generate-exhibits.py \
        --variable-name 'w' --transpose --normalize 'max' --include-average \
        --xlim '-1.0' '0.3' \
        --ylim '-0.65' '0.65' \
        --escape-radius {{ radius }} \
        --outfile structural-conn/exhibit.json --overwrite \
        data/Structural_Conn.mat

[doc('Convert random structural data to JSON')]
gen_structural_random radius='100.0':
    @mkdir -p structural-random
    {{ PYTHON }} scripts/generate-exhibits.py \
        --variable-name 'C_rand' --transpose --normalize 'max' --include-average \
        --xlim '-1.1' '0.4' \
        --ylim '-0.75' '0.75' \
        --escape-radius {{ radius }} \
        --outfile structural-random/exhibit.json --overwrite \
        data/C_rand.mat

[doc('Convert rest data to JSON')]
gen_rest radius='100.0':
    @mkdir -p task-rest
    {{ PYTHON }} scripts/generate-exhibits.py \
        --variable-name 'w' --transpose --include-average \
        --xlim '-0.03' '0.03' \
        --ylim '-0.03' '0.03' \
        --escape-radius {{ radius }} \
        --outfile task-rest/exhibit.json --overwrite \
        data/Rest_LR_Task.mat

[doc('Convert rest data to JSON (in absolute value)')]
gen_rest_abs radius='100.0':
    @mkdir -p task-rest-abs
    {{ PYTHON }} scripts/generate-exhibits.py \
        --variable-name 'w' --transpose --abs \
        --xlim '-0.002' '0.0005' \
        --ylim '-0.00125' '0.00125' \
        --escape-radius {{ radius }} \
        --outfile task-rest-abs/exhibit.json --overwrite \
        data/Rest_LR_Task.mat

[doc('Convert rest data to JSON (positive only)')]
gen_rest_positive radius='100.0':
    @mkdir -p task-rest-positive
    {{ PYTHON }} scripts/generate-exhibits.py \
        --variable-name 'w' --transpose --clip '0.0' 'inf' \
        --xlim '-0.01' '0.003' \
        --ylim '-0.0065' '0.0065' \
        --escape-radius {{ radius }} \
        --outfile task-rest/exhibit.json --overwrite \
        data/Rest_LR_Task.mat

[doc('Convert rest data to JSON (negative only)')]
gen_rest_negative radius='100.0':
    @mkdir -p task-rest-negative
    {{ PYTHON }} scripts/generate-exhibits.py \
        --variable-name 'w' --transpose --clip '-inf' '0.0' \
        --xlim '-0.01' '0.003' \
        --ylim '-0.0065' '0.0065' \
        --escape-radius {{ radius }} \
        --outfile task-rest-negative/exhibit.json --overwrite \
        data/Rest_LR_Task.mat

[doc('Convert all emotion data to JSON')]
gen_emotion radius='100.0':
    @mkdir -p task-emotion
    {{ PYTHON }} scripts/generate-exhibits.py \
        --variable-name 'w' --transpose --include-average \
        --xlim '-0.03' '0.03' \
        --ylim '-0.03' '0.03' \
        --escape-radius {{ radius }} \
        --outfile task-emotion/exhibit.json --overwrite \
        data/Emotion_LR_Task.mat

[doc('Convert all emotion data to JSON (absolute value)')]
gen_emotion_abs radius='100.0':
    @mkdir -p task-emotion-abs
    {{ PYTHON }} scripts/generate-exhibits.py \
        --variable-name 'w' --transpose --abs \
        --xlim '-0.002' '0.0005' \
        --ylim '-0.00125' '0.00125' \
        --escape-radius {{ radius }} \
        --outfile task-emotion-abs/exhibit.json --overwrite \
        data/Emotion_LR_Task.mat

[doc('Convert all emotion data to JSON (positive only)')]
gen_emotion_positive radius='100.0':
    @mkdir -p task-emotion-positive
    {{ PYTHON }} scripts/generate-exhibits.py \
        --variable-name 'w' --transpose --clip '0.0' 'inf' \
        --xlim '-0.01' '0.003' \
        --ylim '-0.0065' '0.0065' \
        --escape-radius {{ radius }} \
        --outfile task-emotion-positive/exhibit.json --overwrite \
        data/Emotion_LR_Task.mat

[doc('Convert all emotion data to JSON (negative only)')]
gen_emotion_negative radius='100.0':
    @mkdir -p task-emotion-negative
    {{ PYTHON }} scripts/generate-exhibits.py \
        --variable-name 'w' --transpose --clip '-inf' '0.0' \
        --xlim '-0.01' '0.003' \
        --ylim '-0.0065' '0.0065' \
        --escape-radius {{ radius }} \
        --outfile task-emotion-negative/exhibit.json --overwrite \
        data/Emotion_LR_Task.mat

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
