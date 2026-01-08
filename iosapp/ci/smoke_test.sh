#!/bin/bash
# ci/smoke_test.sh — quick CPU smoke test (<10 min)
set -e

echo "komal smoke test starting..."

# create temp dirs
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

export DATASET_ROOT=$TEMP_DIR/data
export CHECKPOINT_ROOT=$TEMP_DIR/checkpoints
mkdir -p $DATASET_ROOT $CHECKPOINT_ROOT

# generate tiny synthetic data
python -c "
import torch
import os

# synthetic multimodal data
for split in ['train', 'val']:
    os.makedirs(f'$DATASET_ROOT/{split}', exist_ok=True)
    for i in range(10):
        torch.save({
            'gaze': torch.randn(100, 2),
            'audio': torch.randn(16000),
            'face': torch.randn(30, 3, 112, 112),
            'touch': torch.randn(50, 3),
            'label': torch.randint(0, 5, (1,))
        }, f'$DATASET_ROOT/{split}/sample_{i}.pt')
print('synthetic data created')
"

# test pretrain (minimal config)
echo "testing pretrain pipeline..."
python run_pretrain.py \
    --model_dim 64 \
    --ffn_dim 128 \
    --num_layers 2 \
    --num_heads 4 \
    --batch_size 2 \
    --max_steps 10 \
    --dataset_root $DATASET_ROOT \
    --checkpoint_dir $CHECKPOINT_ROOT \
    --no_cuda \
    --dry_run

# test data loading
echo "testing data loaders..."
python -c "
from data.multimodal_dataset import KomalDataset
ds = KomalDataset('$DATASET_ROOT/train')
print(f'dataset size: {len(ds)}')
sample = ds[0]
print(f'sample keys: {sample.keys()}')
"

# test metrics computation
echo "testing metrics..."
python -c "
from metrics import compute_attention_score, compute_emotion_metrics
import torch
gaze = torch.randn(100, 2)
score = compute_attention_score(gaze)
print(f'attention score: {score:.2f}')
"

echo "smoke test passed!"
