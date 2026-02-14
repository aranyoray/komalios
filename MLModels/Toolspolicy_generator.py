#!/usr/bin/env python3
"""
policy_generator.py
Generates policy bundle from Models_Masterlist.csv at build time
"""

import csv
import json
import re
from collections import defaultdict
from pathlib import Path
import sys

def generate_keywords_from_csv(csv_path):
    """Generate keywords_major.json and keywords_sub.json"""
    
    major_keywords = defaultdict(dict)
    sub_keywords = defaultdict(dict)
    
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            # Skip empty rows
            if not row.get('Category'):
                continue
                
            category = row['Category']
            
            # Parse major category keywords
            total_keywords = row.get('Tokenized_category_keywords_total', '')
            if total_keywords:
                keywords = [k.strip() for k in total_keywords.split(',')]
                for kw in keywords:
                    if kw:
                        # Simple weight based on position
                        weight = 1.0 if keywords.index(kw) < 3 else 0.8
                        major_keywords[map_category(category)][kw] = weight
            
            # Parse subcategory keywords
            subcategory = row.get('Subcategory', '')
            sub_total = row.get('Tokenized_subcategory_keywords_total', '')
            if subcategory and sub_total:
                keywords = [k.strip() for k in sub_total.split(',')]
                subcat_id = f"{category}_{subcategory}".replace(' ', '_').replace('.', '')
                for kw in keywords:
                    if kw:
                        weight = 1.0 if keywords.index(kw) < 3 else 0.8
                        sub_keywords[subcat_id][kw] = weight
    
    return dict(major_keywords), dict(sub_keywords)

def generate_labels(csv_path):
    """Generate labels_major.json and labels_sub.json"""
    
    labels_major = {}
    labels_sub = {}
    
    category_mapping = {
        "1. Violence & Disturbing Content": "violence",
        "2. Explicit & Body-Related Content": "explicit",
        "3. Substances & Addictive Behavior": "substances",
        "4. Financial & Commercial Content": "financial",
        "5. Media & Platform-Native Risks": "media",
        "6. Social & Cultural Topics": "social"
    }
    
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            if not row.get('Category'):
                continue
                
            category = row['Category']
            subcategory = row.get('Subcategory', '')
            
            # Major labels
            if category in category_mapping:
                labels_major[category] = category_mapping[category]
            
            # Sub labels
            if subcategory:
                subcat_id = f"{category}_{subcategory}".replace(' ', '_').replace('.', '')
                labels_sub[subcat_id] = {
                    "id": subcat_id,
                    "parentMajor": category_mapping.get(category, "unknown"),
                    "name": subcategory
                }
    
    return labels_major, labels_sub

def generate_age_rules(csv_path):
    """Generate age_rules.json"""
    
    age_rules = {}
    
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            if not row.get('Category'):
                continue
                
            category = map_category(row['Category'])
            
            age_rules[category] = {
                "below10": row.get('rules_below_10', 'Block').upper(),
                "age10to13": row.get('rules_10_13', 'Block').upper(),
                "age13to16": row.get('rules_13_16', 'Gate').upper(),
                "age16to18": row.get('rules_16_18', 'Allow').upper()
            }
    
    return age_rules

def generate_thresholds(csv_path):
    """Generate thresholds.json"""
    
    thresholds = {}
    
    # Ban-sensitive categories require lower thresholds
    ban_sensitive = {"explicit", "violence", "self_harm", "extremism"}
    
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            if not row.get('Category'):
                continue
                
            category = map_category(row['Category'])
            
            is_ban_sensitive = category in ban_sensitive
            
            thresholds[category] = {
                "blockThreshold": 0.6 if is_ban_sensitive else 0.7,
                "gateThreshold": 0.3 if is_ban_sensitive else 0.4,
                "banSensitive": is_ban_sensitive
            }
    
    return thresholds

def map_category(category_name):
    """Map category name to enum value"""
    mapping = {
        "1. Violence & Disturbing Content": "violence",
        "2. Explicit & Body-Related Content": "explicit",
        "3. Substances & Addictive Behavior": "substances",
        "4. Financial & Commercial Content": "financial",
        "5. Media & Platform-Native Risks": "media",
        "6. Social & Cultural Topics": "social"
    }
    return mapping.get(category_name, "unknown")

def generate_schema(csv_path):
    """Generate schema.json with output structure"""
    
    schema = {
        "version": "1.0",
        "structure": {
            "overall_safety_score": "float 0-1",
            "language_safety_score": "float 0-1",
            "visual_safety_score": "float 0-1",
            "age_actions": {
                "<10": {"action": "BLOCK|GATE|ALLOW", "score": "float 0-1"},
                "10-13": {"action": "BLOCK|GATE|ALLOW", "score": "float 0-1"},
                "13-16": {"action": "BLOCK|GATE|ALLOW", "score": "float 0-1"},
                "16+": {"action": "BLOCK|GATE|ALLOW", "score": "float 0-1"}
            },
            "context_type": "string",
            "topic_tags": ["array of strings"],
            "lgbtq_flag": {
                "present": "bool",
                "type": "identity|education|hate|fetishization"
            },
            "harm_flag": {
                "body_anxiety": "bool",
                "self_harm": "bool",
                "fraud_or_scam": "bool",
                "extremism": "bool"
            }
        }
    }
    
    return schema

def main():
    if len(sys.argv) < 3:
        print("Usage: policy_generator.py <input_csv> <output_dir>")
        sys.exit(1)
    
    csv_path = Path(sys.argv[1])
    output_dir = Path(sys.argv[2])
    output_dir.mkdir(parents=True, exist_ok=True)
    
    print(f"Generating policy bundle from {csv_path}")
    
    # Generate all artifacts
    major_keywords, sub_keywords = generate_keywords_from_csv(csv_path)
    labels_major, labels_sub = generate_labels(csv_path)
    age_rules = generate_age_rules(csv_path)
    thresholds = generate_thresholds(csv_path)
    schema = generate_schema(csv_path)
    
    # Write to JSON files
    with open(output_dir / 'keywords_major.json', 'w') as f:
        json.dump(major_keywords, f, indent=2)
    
    with open(output_dir / 'keywords_sub.json', 'w') as f:
        json.dump(sub_keywords, f, indent=2)
    
    with open(output_dir / 'labels_major.json', 'w') as f:
        json.dump(labels_major, f, indent=2)
    
    with open(output_dir / 'labels_sub.json', 'w') as f:
        json.dump(labels_sub, f, indent=2)
    
    with open(output_dir / 'age_rules.json', 'w') as f:
        json.dump(age_rules, f, indent=2)
    
    with open(output_dir / 'thresholds.json', 'w') as f:
        json.dump(thresholds, f, indent=2)
    
    with open(output_dir / 'schema.json', 'w') as f:
        json.dump(schema, f, indent=2)
    
    print(f"✓ Generated policy bundle in {output_dir}")
    print(f"  - keywords_major.json: {len(major_keywords)} categories")
    print(f"  - keywords_sub.json: {len(sub_keywords)} subcategories")
    print(f"  - labels_major.json: {len(labels_major)} major labels")
    print(f"  - labels_sub.json: {len(labels_sub)} sub labels")
    print(f"  - age_rules.json: {len(age_rules)} rule sets")
    print(f"  - thresholds.json: {len(thresholds)} threshold configs")
    print(f"  - schema.json: Output structure")

if __name__ == '__main__':
    main()
