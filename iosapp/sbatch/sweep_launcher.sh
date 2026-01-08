#!/bin/bash
# sbatch/sweep_launcher.sh — hydra/submitit sweep launcher
#SBATCH --job-name=komal_sweep
#SBATCH --partition={{SLURM_PARTITION}}
#SBATCH --gpus=2
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=48:00:00
#SBATCH --output={{OUTPUT_ROOT}}/logs/sweep_%j.out

export DATASET_ROOT={{DATASET_ROOT}}
export CHECKPOINT_ROOT={{CHECKPOINT_ROOT}}

source /opt/conda/etc/profile.d/conda.sh
conda activate komal

python -m submitit_train \
    --multirun \
    --config-name=sweep_komal \
    hydra/launcher=submitit_slurm \
    hydra.launcher.partition={{SLURM_PARTITION}} \
    hydra.launcher.gpus_per_node=2 \
    hydra.launcher.timeout_min=720 \
    hydra.sweep.dir=$CHECKPOINT_ROOT/sweeps
