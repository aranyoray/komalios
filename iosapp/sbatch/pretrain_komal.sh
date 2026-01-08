#!/bin/bash
# sbatch/pretrain_komal.sh — SLURM script for 8×A100 multimodal pretrain (~600M-1B params)
#SBATCH --job-name=komal_pretrain
#SBATCH --partition={{SLURM_PARTITION}}
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=8
#SBATCH --gpus-per-node=8
#SBATCH --cpus-per-task=12
#SBATCH --mem=480G
#SBATCH --time=72:00:00
#SBATCH --output={{OUTPUT_ROOT}}/logs/pretrain_%j.out
#SBATCH --error={{OUTPUT_ROOT}}/logs/pretrain_%j.err

# editable env vars
export DATASET_ROOT={{DATASET_ROOT}}
export CHECKPOINT_ROOT={{CHECKPOINT_ROOT}}
export S3_BUCKET={{S3_BUCKET}}
export WANDB_PROJECT=komal_pretrain

# model config (edit as needed)
MODEL_DIM=1024
FFN_DIM=4096
LAYERS=24
HEADS=16
BATCH_SIZE=32
GRAD_ACCUM=4
LR=1e-4
WARMUP_STEPS=10000
TOTAL_STEPS=800000
CHECKPOINT_INTERVAL=5000

# activate env
source /opt/conda/etc/profile.d/conda.sh
conda activate komal

# distributed training
torchrun --nproc_per_node=8 --master_port=29500 \
    run_pretrain.py \
    --model_dim $MODEL_DIM \
    --ffn_dim $FFN_DIM \
    --num_layers $LAYERS \
    --num_heads $HEADS \
    --batch_size $BATCH_SIZE \
    --gradient_accumulation_steps $GRAD_ACCUM \
    --learning_rate $LR \
    --warmup_steps $WARMUP_STEPS \
    --max_steps $TOTAL_STEPS \
    --weight_decay 0.01 \
    --adam_beta1 0.9 \
    --adam_beta2 0.98 \
    --fp16 \
    --use_fsdp \
    --activation_checkpointing \
    --offload_optimizer \
    --prefetch_to_nvme \
    --dataset_root $DATASET_ROOT \
    --checkpoint_dir $CHECKPOINT_ROOT/pretrain \
    --checkpoint_interval $CHECKPOINT_INTERVAL \
    --resume_from_checkpoint auto \
    --log_dir $CHECKPOINT_ROOT/logs \
    --wandb_project $WANDB_PROJECT \
    --modalities gaze,audio,face,touch \
    --mask_ratio 0.15 \
    --num_workers 8 \
    --prefetch_factor 4
