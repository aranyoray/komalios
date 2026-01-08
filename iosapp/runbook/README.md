# Komal ML Pipeline Runbook

## Required Environment Variables

```bash
export DATASET_ROOT=/path/to/komal/data          # multimodal dataset location
export CHECKPOINT_ROOT=/path/to/checkpoints      # model checkpoints
export OUTPUT_ROOT=/path/to/outputs              # logs, results, reports
export S3_BUCKET=s3://komal-artifacts            # remote artifact storage
export SLURM_PARTITION=gpu                       # cluster partition name
export WANDB_API_KEY=xxx                         # weights & biases key
```

## Editable Hyperparameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| PRETRAIN_STEPS | 800000 | Total pretraining steps |
| BATCH_SIZE | 32 | Per-GPU batch size |
| LR | 1e-4 | Peak learning rate |
| LAYERS | 24 | Transformer layers |
| MODEL_DIM | 1024 | Hidden dimension |
| FFN_DIM | 4096 | FFN intermediate dim |
| WARMUP_STEPS | 10000 | LR warmup steps |

## Monitoring Checklist

- [ ] **Disk usage**: Alert if /checkpoints >90% full
- [ ] **NVMe prefetch**: Verify prefetch logs show >90% hit rate
- [ ] **TensorBoard**: `tensorboard --logdir $CHECKPOINT_ROOT/logs`
- [ ] **W&B**: Check loss curves, gradient norms, learning rate
- [ ] **Prometheus alerts**: OOM kills, GPU util <50%, checkpoint failures
- [ ] **Checkpoint frequency**: Verify saves every 5000 steps
- [ ] **Validation loss**: Monitor for divergence every 1000 steps

## Quick Start Commands

```bash
# 1. build and push docker image
docker build -t komal:latest -f docker/Dockerfile .
docker push {{DOCKER_REGISTRY}}/komal:latest

# 2. run smoke test
bash ci/smoke_test.sh

# 3. launch pretrain
sbatch sbatch/pretrain_komal.sh

# 4. launch sweep
sbatch sbatch/sweep_launcher.sh

# 5. monitor
watch -n 30 squeue -u $USER
```

## Privacy & Safety Mitigations

**Data Handling:**
- All face/gaze/child data encrypted at rest (AES-256)
- Access logs enabled on S3 bucket
- PII stored in restricted bucket with IAM policies
- Federated mode recommended for production deployments

**Model Safety:**
- DP-SGD enabled for federated training (ε=8.0)
- Secure aggregation for gradient updates
- Clinical escalation flags for concerning patterns
- Regular bias audits on demographic splits

**Compliance:**
- Parental consent required before data collection
- Follow COPPA (US), GDPR (EU), local regulations
- Consult legal counsel for deployment-specific requirements
- Data retention policy: delete raw data after 2 years

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| OOM on A100 | Batch too large | Reduce BATCH_SIZE or increase GRAD_ACCUM |
| Slow I/O | NFS bottleneck | Enable --prefetch_to_nvme, use local SSD |
| Checkpoint corrupt | Interrupted save | Enable --atomic_save, check disk space |
| Loss NaN | LR too high | Reduce LR, enable gradient clipping |
| Stuck at 0% | Data loading | Check DATASET_ROOT path, num_workers |
