#!/bin/bash
# reports/generate_report.sh — aggregate metrics and generate PDF report
set -e

export CHECKPOINT_ROOT={{CHECKPOINT_ROOT}}
export OUTPUT_ROOT={{OUTPUT_ROOT}}

REPORT_DIR=$OUTPUT_ROOT/reports
mkdir -p $REPORT_DIR

# collect metrics from all experiments
python collect_metrics.py \
    --sweep_dir $CHECKPOINT_ROOT/sweeps \
    --pretrain_dir $CHECKPOINT_ROOT/pretrain \
    --federated_dir $CHECKPOINT_ROOT/federated \
    --xgen_dir $CHECKPOINT_ROOT/xgen \
    --output_csv $REPORT_DIR/all_metrics.csv

# generate latex report
python generate_latex_report.py \
    --metrics_csv $REPORT_DIR/all_metrics.csv \
    --template reports/templates/progress_report.tex \
    --output_tex $REPORT_DIR/komal_extended_progress_report.tex \
    --include_plots \
    --include_tables

# compile to pdf
cd $REPORT_DIR
pdflatex -interaction=nonstopmode komal_extended_progress_report.tex
pdflatex -interaction=nonstopmode komal_extended_progress_report.tex  # run twice for refs

# generate clinician summary (single page)
python generate_clinician_summary.py \
    --metrics_csv $REPORT_DIR/all_metrics.csv \
    --output_md $REPORT_DIR/clinician_summary.md

pandoc $REPORT_DIR/clinician_summary.md \
    -o $REPORT_DIR/clinician_summary.pdf \
    --pdf-engine=pdflatex \
    -V geometry:margin=1in

echo "reports generated:"
echo "  - $REPORT_DIR/komal_extended_progress_report.pdf"
echo "  - $REPORT_DIR/clinician_summary.pdf"
