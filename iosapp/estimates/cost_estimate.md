# Komal Infrastructure Cost Estimate

**Note:** All costs are estimates. Edit {{RATE_PER_GPU_HOUR}} based on your cloud provider.

## GPU-Hour Breakdown

| Task | GPUs | Hours | GPU-Hours | Cost @ $3/hr |
|------|------|-------|-----------|--------------|
| **Pretrain** (800k steps) | 8×A100 | 72 | 576 | $1,728 |
| **Sweep** (2000 configs) | 2×A100 | 2 avg | 4,000 | $12,000 |
| **Federated Sim** (500 rounds) | 16×A100 | 48 | 768 | $2,304 |
| **Cross-gen Array** (5 datasets) | 2×A100 | 12 | 120 | $360 |
| **Causal Pipeline** | 1×A100 | 24 | 24 | $72 |
| **Micro-exp Finetune** | 4×A100 | 24 | 96 | $288 |
| **Benchmarking** | 1×A100 | 4 | 4 | $12 |

### Total Estimate

| Category | GPU-Hours | Cost ({{RATE_PER_GPU_HOUR}}=$3/hr) |
|----------|-----------|-----------------------------------|
| Core Training | 576 | $1,728 |
| Hyperparameter Search | 4,000 | $12,000 |
| Federated Learning | 768 | $2,304 |
| Evaluation & Analysis | 244 | $732 |
| **Total** | **5,588** | **$16,764** |

## Storage Costs

| Item | Size | Monthly Cost |
|------|------|--------------|
| Raw dataset | 2 TB | $46 (S3 Standard) |
| Checkpoints | 500 GB | $12 |
| Logs & artifacts | 200 GB | $5 |
| **Total Storage** | 2.7 TB | **$63/month** |

## Compute Options

| Provider | GPU Type | $/hr | Notes |
|----------|----------|------|-------|
| AWS p4d.24xlarge | 8×A100 | $32.77 | On-demand |
| AWS Spot | 8×A100 | ~$10-15 | Interruption risk |
| GCP a2-ultragpu-8g | 8×A100 | $29.39 | On-demand |
| Lambda Labs | 8×A100 | $12.00 | Reserved |
| RunPod | 8×A100 | $15.00 | On-demand |

## Cost Reduction Strategies

1. **Spot instances**: 60-70% savings, use checkpointing
2. **Mixed precision**: 2x throughput, same cost
3. **Gradient checkpointing**: Fit larger batch, fewer steps
4. **Early stopping**: Kill poor sweep configs early
5. **Preemptible VMs**: For non-critical experiments

---
*Edit {{RATE_PER_GPU_HOUR}} and storage costs for your specific provider.*
