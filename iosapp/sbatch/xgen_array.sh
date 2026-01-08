#!/bin/bash
# sbatch/xgen_array.sh — array job for cross-dataset generalization (MMD/Fréchet)
#SBATCH --job-name=komal_xgen
#SBATCH --partition={{SLURM_PARTITION}}
#SBATCH --array=0-4
#SBATCH --gpus=2
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=12:00:00
#SBATCH --output={{OUTPUT_ROOT}}/logs/xgen_%A_%a.out

export DATASET_ROOT={{DATASET_ROOT}}
export CHECKPOINT_ROOT={{CHECKPOINT_ROOT}}

DATASETS=("komal_main" "affectnet" "fer2013" "rafdb" "expw")
TRAIN_DS=${DATASETS[$SLURM_ARRAY_TASK_ID]}

source /opt/conda/etc/profile.d/conda.sh
conda activate komal

# train on one dataset
python run_xgen_train.py \
    --train_dataset $TRAIN_DS \
    --dataset_root $DATASET_ROOT \
    --output_dir $CHECKPOINT_ROOT/xgen/$TRAIN_DS \
    --epochs 50 \
    --batch_size 64 \
    --fp16

# evaluate on all datasets and compute distances
for EVAL_DS in "${DATASETS[@]}"; do
    python run_xgen_eval.py \
        --model_path $CHECKPOINT_ROOT/xgen/$TRAIN_DS/best.pt \
        --eval_dataset $EVAL_DS \
        --dataset_root $DATASET_ROOT \
        --output_dir $CHECKPOINT_ROOT/xgen/results \
        --compute_mmd \
        --compute_frechet
done

# aggregate results
if [ $SLURM_ARRAY_TASK_ID -eq 4 ]; then
    sleep 60  # wait for other jobs
    python aggregate_xgen.py \
        --input_dir $CHECKPOINT_ROOT/xgen/results \
        --output_csv $CHECKPOINT_ROOT/xgen/xgen_matrix.csv
fi
