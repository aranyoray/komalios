#!/bin/bash
# sbatch/microexp_finetune.sh — micro-expression detection finetune
#SBATCH --job-name=komal_microexp
#SBATCH --partition={{SLURM_PARTITION}}
#SBATCH --gpus=4
#SBATCH --cpus-per-task=16
#SBATCH --mem=128G
#SBATCH --time=24:00:00
#SBATCH --output={{OUTPUT_ROOT}}/logs/microexp_%j.out

export DATASET_ROOT={{DATASET_ROOT}}
export CHECKPOINT_ROOT={{CHECKPOINT_ROOT}}

# class weights (edit for your dataset imbalance)
CLASS_WEIGHTS="1.0,2.5,3.0,1.5,4.0,2.0,1.8"

source /opt/conda/etc/profile.d/conda.sh
conda activate komal

torchrun --nproc_per_node=4 \
    run_microexp_finetune.py \
    --model_type spatiotemporal_transformer \
    --backbone r2plus1d_18 \
    --pretrained_path $CHECKPOINT_ROOT/pretrain/best.pt \
    --dataset_root $DATASET_ROOT/microexp \
    --output_dir $CHECKPOINT_ROOT/microexp \
    --frame_rate 200 \
    --clip_length 64 \
    --num_classes 7 \
    --batch_size 16 \
    --epochs 100 \
    --lr 1e-4 \
    --weight_decay 0.01 \
    --fp16 \
    --balanced_sampler \
    --focal_loss \
    --focal_gamma 2.0 \
    --class_weights $CLASS_WEIGHTS \
    --temporal_augment \
    --mixup_alpha 0.2 \
    --label_smoothing 0.1 \
    --early_stopping_patience 15
