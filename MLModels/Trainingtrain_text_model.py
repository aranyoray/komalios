#!/usr/bin/env python3
"""
train_text_model.py
Complete training pipeline for safety classification model
"""

import argparse
import json
import numpy as np
import pandas as pd
from pathlib import Path
import torch
import torch.nn as nn
from torch.utils.data import Dataset, DataLoader
from transformers import AutoModel, AutoTokenizer, AdamW, get_linear_schedule_with_warmup
from sklearn.model_selection import train_test_split
from sklearn.metrics import f1_score, precision_score, recall_score
from tqdm import tqdm
import coremltools as ct

# ============================================================================
# 1. Dataset Preparation
# ============================================================================

class SafetyDataset(Dataset):
    """Multi-label safety classification dataset"""
    
    def __init__(self, texts, labels, tokenizer, max_length=384):
        self.texts = texts
        self.labels = labels  # Shape: (N, num_labels)
        self.tokenizer = tokenizer
        self.max_length = max_length
    
    def __len__(self):
        return len(self.texts)
    
    def __getitem__(self, idx):
        text = self.texts[idx]
        label = self.labels[idx]
        
        encoding = self.tokenizer(
            text,
            max_length=self.max_length,
            padding='max_length',
            truncation=True,
            return_tensors='pt'
        )
        
        return {
            'input_ids': encoding['input_ids'].squeeze(0),
            'attention_mask': encoding['attention_mask'].squeeze(0),
            'labels': torch.FloatTensor(label)
        }

def load_training_data(data_dir, keywords_path):
    """Load and prepare training data from CSV + scraped datasets"""
    
    # Load keywords for sampling
    with open(keywords_path) as f:
        keywords = json.load(f)
    
    # Category mapping
    category_map = {
        'violence': 0,
        'explicit': 1,
        'substances': 2,
        'financial': 3,
        'media': 4,
        'social': 5
    }
    
    texts = []
    labels = []
    
    # 1. Load from datasets mentioned in CSV
    violence_df = pd.read_csv(f"{data_dir}/violence_dataset.csv")
    for _, row in violence_df.iterrows():
        texts.append(row['text'])
        label = np.zeros(6)
        label[category_map['violence']] = 1.0
        labels.append(label)
    
    # 2. Load NSFW dataset
    nsfw_df = pd.read_csv(f"{data_dir}/nsfw_text_dataset.csv")
    for _, row in nsfw_df.iterrows():
        texts.append(row['text'])
        label = np.zeros(6)
        label[category_map['explicit']] = 1.0
        labels.append(label)
    
    # 3. Load hate speech dataset
    hate_df = pd.read_csv(f"{data_dir}/hate_speech_dataset.csv")
    for _, row in hate_df.iterrows():
        texts.append(row['text'])
        label = np.zeros(6)
        label[category_map['social']] = 1.0
        labels.append(label)
    
    # 4. Load gambling/financial dataset
    gambling_df = pd.read_csv(f"{data_dir}/gambling_dataset.csv")
    for _, row in gambling_df.iterrows():
        texts.append(row['text'])
        label = np.zeros(6)
        label[category_map['substances']] = 1.0
        labels.append(label)
    
    # 5. Generate synthetic examples using keywords
    for category, kws in keywords.items():
        if category not in category_map:
            continue
        
        for kw, weight in list(kws.items())[:20]:  # Top 20 keywords
            # Generate simple sentence
            synthetic_text = f"This content contains {kw} and related material."
            texts.append(synthetic_text)
            label = np.zeros(6)
            label[category_map[category]] = weight
            labels.append(label)
    
    return texts, np.array(labels)

# ============================================================================
# 2. Model Definition
# ============================================================================

class SafetyClassifier(nn.Module):
    """Multi-label transformer-based classifier"""
    
    def __init__(self, base_model_name, num_major=6, num_sub=50):
        super().__init__()
        self.base = AutoModel.from_pretrained(base_model_name)
        hidden_size = self.base.config.hidden_size
        
        # Major category head (multi-label sigmoid)
        self.major_head = nn.Sequential(
            nn.Dropout(0.1),
            nn.Linear(hidden_size, hidden_size // 2),
            nn.ReLU(),
            nn.Dropout(0.1),
            nn.Linear(hidden_size // 2, num_major)
        )
        
        # Subcategory head (routed, also multi-label)
        self.sub_head = nn.Sequential(
            nn.Dropout(0.1),
            nn.Linear(hidden_size, hidden_size // 2),
            nn.ReLU(),
            nn.Dropout(0.1),
            nn.Linear(hidden_size // 2, num_sub)
        )
    
    def forward(self, input_ids, attention_mask):
        outputs = self.base(
            input_ids=input_ids,
            attention_mask=attention_mask
        )
        
        # Use [CLS] token
        pooled = outputs.last_hidden_state[:, 0, :]
        
        major_logits = self.major_head(pooled)
        sub_logits = self.sub_head(pooled)
        
        return major_logits, sub_logits

# ============================================================================
# 3. Training Loop
# ============================================================================

def train_epoch(model, dataloader, optimizer, scheduler, device):
    """Train for one epoch"""
    model.train()
    total_loss = 0
    criterion = nn.BCEWithLogitsLoss()
    
    pbar = tqdm(dataloader, desc="Training")
    for batch in pbar:
        input_ids = batch['input_ids'].to(device)
        attention_mask = batch['attention_mask'].to(device)
        labels = batch['labels'].to(device)
        
        optimizer.zero_grad()
        
        major_logits, sub_logits = model(input_ids, attention_mask)
        
        # Loss on major categories
        loss = criterion(major_logits, labels)
        
        loss.backward()
        torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
        optimizer.step()
        scheduler.step()
        
        total_loss += loss.item()
        pbar.set_postfix({'loss': loss.item()})
    
    return total_loss / len(dataloader)

def evaluate(model, dataloader, device):
    """Evaluate model"""
    model.eval()
    all_preds = []
    all_labels = []
    
    with torch.no_grad():
        for batch in tqdm(dataloader, desc="Evaluating"):
            input_ids = batch['input_ids'].to(device)
            attention_mask = batch['attention_mask'].to(device)
            labels = batch['labels'].to(device)
            
            major_logits, _ = model(input_ids, attention_mask)
            preds = torch.sigmoid(major_logits)
            
            all_preds.append(preds.cpu().numpy())
            all_labels.append(labels.cpu().numpy())
    
    all_preds = np.vstack(all_preds)
    all_labels = np.vstack(all_labels)
    
    # Threshold at 0.5
    all_preds = (all_preds > 0.5).astype(int)
    
    # Compute metrics per category
    f1_micro = f1_score(all_labels, all_preds, average='micro')
    f1_macro = f1_score(all_labels, all_preds, average='macro')
    precision = precision_score(all_labels, all_preds, average='macro', zero_division=0)
    recall = recall_score(all_labels, all_preds, average='macro', zero_division=0)
    
    return {
        'f1_micro': f1_micro,
        'f1_macro': f1_macro,
        'precision': precision,
        'recall': recall
    }

# ============================================================================
# 4. Export to CoreML
# ============================================================================

def export_to_coreml(model, tokenizer, output_path, quantize='w8a8'):
    """Export trained model to CoreML with quantization"""
    
    model.eval()
    
    # Trace model
    example_input = torch.randint(0, tokenizer.vocab_size, (1, 384))
    example_mask = torch.ones(1, 384, dtype=torch.long)
    
    traced = torch.jit.trace(model, (example_input, example_mask))
    
    # Convert to CoreML
    mlmodel = ct.convert(
        traced,
        inputs=[
            ct.TensorType(name="input_ids", shape=(1, 384), dtype=np.int32),
            ct.TensorType(name="attention_mask", shape=(1, 384), dtype=np.int32)
        ],
        outputs=[
            ct.TensorType(name="major_logits"),
            ct.TensorType(name="sub_logits")
        ],
        compute_units=ct.ComputeUnit.CPU_AND_NE,
        minimum_deployment_target=ct.target.iOS17
    )
    
    # Quantize
    if quantize == 'w8a8':
        print("Applying W8A8 quantization...")
        mlmodel = ct.optimize.coreml.linear_quantize_weights(
            mlmodel,
            mode="linear_symmetric",
            dtype=np.int8
        )
    elif quantize == 'w8':
        print("Applying W8 quantization...")
        mlmodel = ct.optimize.coreml.linear_quantize_weights(
            mlmodel,
            mode="linear",
            dtype=np.int8
        )
    
    # Save
    mlmodel.save(output_path)
    print(f"✓ Saved CoreML model to {output_path}")

# ============================================================================
# 5. Main Training Script
# ============================================================================

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--data', type=str, required=True, help='Path to training data dir')
    parser.add_argument('--keywords', type=str, required=True, help='Path to keywords_major.json')
    parser.add_argument('--output', type=str, default='SafetyClassifier.mlpackage')
    parser.add_argument('--model', type=str, default='distilbert-base-uncased')
    parser.add_argument('--epochs', type=int, default=3)
    parser.add_argument('--batch-size', type=int, default=16)
    parser.add_argument('--lr', type=float, default=2e-5)
    parser.add_argument('--max-length', type=int, default=384)
    parser.add_argument('--quantize', type=str, default='w8a8', choices=['none', 'w8', 'w8a8'])
    args = parser.parse_args()
    
    device = torch.device('cuda' if torch.cuda.is_available() else 'mps' if torch.backends.mps.is_available() else 'cpu')
    print(f"Using device: {device}")
    
    # 1. Load data
    print("Loading training data...")
    texts, labels = load_training_data(args.data, args.keywords)
    
    # Split
    train_texts, val_texts, train_labels, val_labels = train_test_split(
        texts, labels, test_size=0.1, random_state=42
    )
    
    print(f"Train samples: {len(train_texts)}, Val samples: {len(val_texts)}")
    
    # 2. Create datasets
    tokenizer = AutoTokenizer.from_pretrained(args.model)
    
    train_dataset = SafetyDataset(train_texts, train_labels, tokenizer, args.max_length)
    val_dataset = SafetyDataset(val_texts, val_labels, tokenizer, args.max_length)
    
    train_loader = DataLoader(train_dataset, batch_size=args.batch_size, shuffle=True)
    val_loader = DataLoader(val_dataset, batch_size=args.batch_size)
    
    # 3. Initialize model
    print(f"Initializing model: {args.model}")
    model = SafetyClassifier(args.model)
    model.to(device)
    
    # 4. Setup optimizer
    optimizer = AdamW(model.parameters(), lr=args.lr)
    total_steps = len(train_loader) * args.epochs
    scheduler = get_linear_schedule_with_warmup(
        optimizer,
        num_warmup_steps=int(0.1 * total_steps),
        num_training_steps=total_steps
    )
    
    # 5. Training loop
    best_f1 = 0
    for epoch in range(args.epochs):
        print(f"\n=== Epoch {epoch + 1}/{args.epochs} ===")
        
        train_loss = train_epoch(model, train_loader, optimizer, scheduler, device)
        print(f"Train loss: {train_loss:.4f}")
        
        metrics = evaluate(model, val_loader, device)
        print(f"Val metrics: F1-micro={metrics['f1_micro']:.4f}, "
              f"F1-macro={metrics['f1_macro']:.4f}, "
              f"Precision={metrics['precision']:.4f}, "
              f"Recall={metrics['recall']:.4f}")
        
        if metrics['f1_macro'] > best_f1:
            best_f1 = metrics['f1_macro']
            torch.save(model.state_dict(), 'best_model.pth')
            print(f"✓ Saved best model (F1={best_f1:.4f})")
    
    # 6. Load best model and export
    print("\nLoading best model for export...")
    model.load_state_dict(torch.load('best_model.pth'))
    
    print("Exporting to CoreML...")
    export_to_coreml(model, tokenizer, args.output, args.quantize)
    
    print(f"\n✓ Training complete! Best F1: {best_f1:.4f}")
    print(f"✓ Model saved to: {args.output}")

if __name__ == '__main__':
    main()
