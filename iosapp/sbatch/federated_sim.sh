#!/bin/bash
# sbatch/federated_sim.sh — federated learning simulation (200 clients, DP, secure agg)
#SBATCH --job-name=komal_federated
#SBATCH --partition={{SLURM_PARTITION}}
#SBATCH --nodes=4
#SBATCH --ntasks-per-node=1
#SBATCH --gpus-per-node=4
#SBATCH --cpus-per-task=16
#SBATCH --mem=128G
#SBATCH --time=48:00:00
#SBATCH --output={{OUTPUT_ROOT}}/logs/federated_%j.out

export DATASET_ROOT={{DATASET_ROOT}}
export CHECKPOINT_ROOT={{CHECKPOINT_ROOT}}

source /opt/conda/etc/profile.d/conda.sh
conda activate komal

# federated config
NUM_CLIENTS=200
NUM_ROUNDS=500
LOCAL_EPOCHS=5
DP_EPSILON=8.0
DP_DELTA=1e-5
NOISE_MULTIPLIER=1.1
CLIP_NORM=1.0

python run_federated.py \
    --num_clients $NUM_CLIENTS \
    --num_rounds $NUM_ROUNDS \
    --local_epochs $LOCAL_EPOCHS \
    --client_fraction 0.1 \
    --dataset_root $DATASET_ROOT \
    --output_dir $CHECKPOINT_ROOT/federated \
    --dp_enabled \
    --dp_epsilon $DP_EPSILON \
    --dp_delta $DP_DELTA \
    --noise_multiplier $NOISE_MULTIPLIER \
    --clip_norm $CLIP_NORM \
    --secure_aggregation \
    --client_heterogeneity non_iid \
    --alpha 0.5 \
    --fp16 \
    --log_communication_bytes \
    --save_dp_report

# generate privacy report
python compute_dp_budget.py \
    --log_dir $CHECKPOINT_ROOT/federated/logs \
    --output $CHECKPOINT_ROOT/federated/dp_epsilon_report.json
