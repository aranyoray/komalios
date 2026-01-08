#!/usr/bin/env python3
"""
run_pretrain.py — Main pretraining script for Komal multimodal transformer.

Supports FSDP, DeepSpeed, gradient checkpointing, mixed precision, and NVMe offload.
"""

import os
import sys
import argparse
import logging
import math
import json
from pathlib import Path
from datetime import datetime

import torch
import torch.nn as nn
import torch.distributed as dist
from torch.utils.data import DataLoader, DistributedSampler
from torch.cuda.amp import GradScaler, autocast
from torch.distributed.fsdp import FullyShardedDataParallel as FSDP
from torch.distributed.fsdp.wrap import transformer_auto_wrap_policy

import numpy as np
from tqdm import tqdm

# local imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from models.multimodal_transformer import create_model, MultimodalTransformer
from data.multimodal_dataset import KomalMultimodalDataset

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Komal Multimodal Pretraining')

    # model architecture
    parser.add_argument('--model_dim', type=int, default=768)
    parser.add_argument('--ffn_dim', type=int, default=3072)
    parser.add_argument('--num_layers', type=int, default=12)
    parser.add_argument('--num_heads', type=int, default=12)
    parser.add_argument('--dropout', type=float, default=0.1)
    parser.add_argument('--mask_ratio', type=float, default=0.15)

    # training
    parser.add_argument('--batch_size', type=int, default=32)
    parser.add_argument('--gradient_accumulation_steps', type=int, default=1)
    parser.add_argument('--learning_rate', type=float, default=1e-4)
    parser.add_argument('--weight_decay', type=float, default=0.01)
    parser.add_argument('--adam_beta1', type=float, default=0.9)
    parser.add_argument('--adam_beta2', type=float, default=0.98)
    parser.add_argument('--adam_epsilon', type=float, default=1e-8)
    parser.add_argument('--max_grad_norm', type=float, default=1.0)
    parser.add_argument('--warmup_steps', type=int, default=10000)
    parser.add_argument('--max_steps', type=int, default=100000)

    # precision and optimization
    parser.add_argument('--fp16', action='store_true')
    parser.add_argument('--bf16', action='store_true')
    parser.add_argument('--use_fsdp', action='store_true')
    parser.add_argument('--activation_checkpointing', action='store_true')
    parser.add_argument('--offload_optimizer', action='store_true')
    parser.add_argument('--prefetch_to_nvme', action='store_true')

    # data
    parser.add_argument('--dataset_root', type=str, required=True)
    parser.add_argument('--modalities', type=str, default='gaze,audio,face,touch')
    parser.add_argument('--num_workers', type=int, default=4)
    parser.add_argument('--prefetch_factor', type=int, default=2)

    # checkpointing
    parser.add_argument('--checkpoint_dir', type=str, required=True)
    parser.add_argument('--checkpoint_interval', type=int, default=5000)
    parser.add_argument('--resume_from_checkpoint', type=str, default=None)

    # logging
    parser.add_argument('--log_dir', type=str, default=None)
    parser.add_argument('--log_interval', type=int, default=100)
    parser.add_argument('--wandb_project', type=str, default=None)

    # misc
    parser.add_argument('--seed', type=int, default=42)
    parser.add_argument('--no_cuda', action='store_true')
    parser.add_argument('--dry_run', action='store_true')
    parser.add_argument('--local_rank', type=int, default=-1)

    return parser.parse_args()


def setup_distributed():
    """Initialize distributed training."""
    if 'RANK' in os.environ:
        rank = int(os.environ['RANK'])
        world_size = int(os.environ['WORLD_SIZE'])
        local_rank = int(os.environ['LOCAL_RANK'])

        dist.init_process_group('nccl')
        torch.cuda.set_device(local_rank)

        return rank, world_size, local_rank
    return 0, 1, 0


def get_lr_scheduler(optimizer, warmup_steps, max_steps):
    """Cosine schedule with linear warmup."""
    def lr_lambda(step):
        if step < warmup_steps:
            return step / warmup_steps
        progress = (step - warmup_steps) / (max_steps - warmup_steps)
        return 0.5 * (1 + math.cos(math.pi * progress))

    return torch.optim.lr_scheduler.LambdaLR(optimizer, lr_lambda)


def save_checkpoint(model, optimizer, scheduler, scaler, step, args, is_best=False):
    """Save training checkpoint."""
    checkpoint_dir = Path(args.checkpoint_dir)
    checkpoint_dir.mkdir(parents=True, exist_ok=True)

    # get model state dict (handle FSDP)
    if args.use_fsdp:
        # FSDP requires special handling
        with FSDP.state_dict_type(model, StateDictType.FULL_STATE_DICT):
            model_state = model.state_dict()
    else:
        model_state = model.state_dict()

    checkpoint = {
        'step': step,
        'model_state_dict': model_state,
        'optimizer_state_dict': optimizer.state_dict(),
        'scheduler_state_dict': scheduler.state_dict(),
        'scaler_state_dict': scaler.state_dict() if scaler else None,
        'args': vars(args),
    }

    # save checkpoint
    checkpoint_path = checkpoint_dir / f'checkpoint_{step}.pt'
    torch.save(checkpoint, checkpoint_path)
    logger.info(f"saved checkpoint to {checkpoint_path}")

    # save best model
    if is_best:
        best_path = checkpoint_dir / 'best.pt'
        torch.save(checkpoint, best_path)

    # save latest for easy resume
    latest_path = checkpoint_dir / 'latest.pt'
    torch.save(checkpoint, latest_path)


def load_checkpoint(model, optimizer, scheduler, scaler, args):
    """Load checkpoint for resuming."""
    checkpoint_path = args.resume_from_checkpoint

    if checkpoint_path == 'auto':
        latest_path = Path(args.checkpoint_dir) / 'latest.pt'
        if latest_path.exists():
            checkpoint_path = str(latest_path)
        else:
            return 0

    if not os.path.exists(checkpoint_path):
        logger.warning(f"checkpoint not found: {checkpoint_path}")
        return 0

    checkpoint = torch.load(checkpoint_path, map_location='cpu')

    model.load_state_dict(checkpoint['model_state_dict'])
    optimizer.load_state_dict(checkpoint['optimizer_state_dict'])
    scheduler.load_state_dict(checkpoint['scheduler_state_dict'])

    if scaler and checkpoint.get('scaler_state_dict'):
        scaler.load_state_dict(checkpoint['scaler_state_dict'])

    step = checkpoint['step']
    logger.info(f"resumed from step {step}")

    return step


def train(args):
    """Main training loop."""
    # setup distributed
    rank, world_size, local_rank = setup_distributed()
    is_main = rank == 0

    # set seed
    torch.manual_seed(args.seed + rank)
    np.random.seed(args.seed + rank)

    # device
    if args.no_cuda:
        device = torch.device('cpu')
    else:
        device = torch.device(f'cuda:{local_rank}')

    # create model
    logger.info("creating model...")
    model = create_model(args)

    # activation checkpointing
    if args.activation_checkpointing:
        from torch.utils.checkpoint import checkpoint_sequential
        model.model.transformer.layers = nn.ModuleList([
            layer for layer in model.model.transformer.layers
        ])
        # enable gradient checkpointing
        for layer in model.model.transformer.layers:
            layer.use_checkpoint = True

    model = model.to(device)

    # FSDP wrapping
    if args.use_fsdp and world_size > 1:
        auto_wrap_policy = transformer_auto_wrap_policy(
            transformer_layer_cls={nn.TransformerEncoderLayer}
        )
        model = FSDP(
            model,
            auto_wrap_policy=auto_wrap_policy,
            cpu_offload=args.offload_optimizer,
        )
    elif world_size > 1:
        model = nn.parallel.DistributedDataParallel(
            model,
            device_ids=[local_rank],
            output_device=local_rank,
        )

    # optimizer
    no_decay = ['bias', 'LayerNorm.weight', 'norm']
    optimizer_grouped_parameters = [
        {
            'params': [p for n, p in model.named_parameters() if not any(nd in n for nd in no_decay)],
            'weight_decay': args.weight_decay,
        },
        {
            'params': [p for n, p in model.named_parameters() if any(nd in n for nd in no_decay)],
            'weight_decay': 0.0,
        },
    ]

    optimizer = torch.optim.AdamW(
        optimizer_grouped_parameters,
        lr=args.learning_rate,
        betas=(args.adam_beta1, args.adam_beta2),
        eps=args.adam_epsilon,
    )

    # scheduler
    scheduler = get_lr_scheduler(optimizer, args.warmup_steps, args.max_steps)

    # mixed precision
    scaler = GradScaler() if args.fp16 else None
    use_amp = args.fp16 or args.bf16
    amp_dtype = torch.float16 if args.fp16 else torch.bfloat16

    # dataset
    logger.info("loading dataset...")
    modalities = args.modalities.split(',')
    dataset = KomalMultimodalDataset(args.dataset_root, modalities=modalities)

    sampler = DistributedSampler(dataset) if world_size > 1 else None
    dataloader = DataLoader(
        dataset,
        batch_size=args.batch_size,
        sampler=sampler,
        shuffle=(sampler is None),
        num_workers=args.num_workers,
        prefetch_factor=args.prefetch_factor,
        pin_memory=True,
        drop_last=True,
    )

    # resume from checkpoint
    start_step = 0
    if args.resume_from_checkpoint:
        start_step = load_checkpoint(model, optimizer, scheduler, scaler, args)

    # wandb logging
    if args.wandb_project and is_main:
        import wandb
        wandb.init(project=args.wandb_project, config=vars(args))

    # training loop
    logger.info(f"starting training from step {start_step}...")
    model.train()

    step = start_step
    running_loss = 0
    data_iter = iter(dataloader)

    # create marker file for k8s readiness probe
    Path(args.checkpoint_dir).mkdir(parents=True, exist_ok=True)
    (Path(args.checkpoint_dir) / 'training_started').touch()

    pbar = tqdm(total=args.max_steps - start_step, disable=not is_main)

    while step < args.max_steps:
        try:
            batch = next(data_iter)
        except StopIteration:
            if sampler:
                sampler.set_epoch(step // len(dataloader))
            data_iter = iter(dataloader)
            batch = next(data_iter)

        # move to device
        batch = {k: v.to(device) if torch.is_tensor(v) else v for k, v in batch.items()}

        # forward pass
        with autocast(enabled=use_amp, dtype=amp_dtype):
            outputs = model(**batch)
            loss = outputs['loss'] / args.gradient_accumulation_steps

        # backward pass
        if scaler:
            scaler.scale(loss).backward()
        else:
            loss.backward()

        running_loss += loss.item() * args.gradient_accumulation_steps

        # optimizer step
        if (step + 1) % args.gradient_accumulation_steps == 0:
            if scaler:
                scaler.unscale_(optimizer)

            # gradient clipping
            torch.nn.utils.clip_grad_norm_(model.parameters(), args.max_grad_norm)

            if scaler:
                scaler.step(optimizer)
                scaler.update()
            else:
                optimizer.step()

            scheduler.step()
            optimizer.zero_grad()

        step += 1
        pbar.update(1)

        # logging
        if step % args.log_interval == 0 and is_main:
            avg_loss = running_loss / args.log_interval
            lr = scheduler.get_last_lr()[0]

            logger.info(f"step {step} | loss {avg_loss:.4f} | lr {lr:.2e}")

            if args.wandb_project:
                import wandb
                wandb.log({
                    'loss': avg_loss,
                    'learning_rate': lr,
                    'step': step,
                })

            running_loss = 0

        # checkpointing
        if step % args.checkpoint_interval == 0 and is_main:
            save_checkpoint(model, optimizer, scheduler, scaler, step, args)

        # dry run
        if args.dry_run and step >= 10:
            logger.info("dry run complete")
            break

    pbar.close()

    # final save
    if is_main:
        save_checkpoint(model, optimizer, scheduler, scaler, step, args, is_best=True)

    logger.info("training complete!")


if __name__ == '__main__':
    args = parse_args()
    train(args)
