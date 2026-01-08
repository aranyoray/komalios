#!/bin/bash
# sbatch/causal_pipeline.sh — causal discovery experiments (PC/GES/ICP/Granger)
#SBATCH --job-name=komal_causal
#SBATCH --partition={{SLURM_PARTITION}}
#SBATCH --gpus=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=128G
#SBATCH --time=24:00:00
#SBATCH --output={{OUTPUT_ROOT}}/logs/causal_%j.out

export DATASET_ROOT={{DATASET_ROOT}}
RESULTS_DIR={{OUTPUT_ROOT}}/results/komal/causal

source /opt/conda/etc/profile.d/conda.sh
conda activate komal

mkdir -p $RESULTS_DIR

ALGORITHMS=("pc" "ges" "icp" "granger" "notears" "dagma")
SEEDS=(42 123 456 789 1024)

# generate synthetic interventions
python generate_interventions.py \
    --data_root $DATASET_ROOT \
    --output_dir $RESULTS_DIR/interventions \
    --num_interventions 1000 \
    --intervention_types do,soft,hard

# run causal discovery
for algo in "${ALGORITHMS[@]}"; do
    for seed in "${SEEDS[@]}"; do
        python run_causal_discovery.py \
            --algorithm $algo \
            --data_root $DATASET_ROOT \
            --intervention_dir $RESULTS_DIR/interventions \
            --output_dir $RESULTS_DIR/$algo \
            --seed $seed \
            --alpha 0.05 \
            --max_cond_vars 5 \
            --bootstrap_samples 500
    done
done

# aggregate and compute SHD/SID metrics
python aggregate_causal.py \
    --input_dir $RESULTS_DIR \
    --output_csv $RESULTS_DIR/causal_summary.csv \
    --compute_shd \
    --compute_sid
