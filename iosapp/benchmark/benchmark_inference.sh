#!/bin/bash
# benchmark/benchmark_inference.sh — latency benchmarks across devices
set -e

export CHECKPOINT_ROOT={{CHECKPOINT_ROOT}}
OUTPUT_DIR={{OUTPUT_ROOT}}/benchmarks

mkdir -p $OUTPUT_DIR

MODEL_PATH=$CHECKPOINT_ROOT/pretrain/best.pt
BATCH_SIZES=(1 4 8)
NUM_RUNS=100

# mobile cpu (arm64 qemu simulation)
echo "benchmarking mobile_cpu..."
for bs in "${BATCH_SIZES[@]}"; do
    python benchmark_inference.py \
        --model_path $MODEL_PATH \
        --device mobile_cpu \
        --batch_size $bs \
        --num_runs $NUM_RUNS \
        --output_json $OUTPUT_DIR/mobile_cpu_bs${bs}.json
done

# webgpu (headless chromium)
echo "benchmarking webgpu..."
for bs in "${BATCH_SIZES[@]}"; do
    python benchmark_inference.py \
        --model_path $MODEL_PATH \
        --device webgpu \
        --batch_size $bs \
        --num_runs $NUM_RUNS \
        --output_json $OUTPUT_DIR/webgpu_bs${bs}.json
done

# edge tpu (simulator)
echo "benchmarking edge_tpu..."
python benchmark_inference.py \
    --model_path $MODEL_PATH \
    --device edge_tpu \
    --batch_size 1 \
    --num_runs $NUM_RUNS \
    --output_json $OUTPUT_DIR/edge_tpu_bs1.json

# cloud gpu (a100)
echo "benchmarking cloud_gpu..."
for bs in "${BATCH_SIZES[@]}"; do
    python benchmark_inference.py \
        --model_path $MODEL_PATH \
        --device cuda \
        --batch_size $bs \
        --num_runs $NUM_RUNS \
        --output_json $OUTPUT_DIR/cloud_gpu_bs${bs}.json
done

# aggregate results
python aggregate_benchmarks.py \
    --input_dir $OUTPUT_DIR \
    --output_csv $OUTPUT_DIR/latency_summary.csv \
    --metrics p50,p95,p99,memory_mb
