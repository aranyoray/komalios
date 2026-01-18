#!/usr/bin/env python3
"""
Template for training CoreML text classification models
Usage: python train_template.py <dataset_name>
Example: python train_template.py horror
"""

import sys
import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, accuracy_score
import coremltools as ct
from coremltools.models import MLModel
from sklearn.pipeline import Pipeline

def train_model(dataset_name):
    """Train and export CoreML model for given dataset"""

    print(f"📊 Loading {dataset_name} dataset...")
    df = pd.read_csv(f'datasets/{dataset_name}_dataset.csv')

    print(f"Dataset size: {len(df)} samples")
    print(f"Label distribution:\n{df['label'].value_counts()}")

    # Split data
    X_train, X_test, y_train, y_test = train_test_split(
        df['text'],
        df['label'],
        test_size=0.2,
        random_state=42,
        stratify=df['label']
    )

    print(f"\n🔨 Training {dataset_name} classifier...")

    # Create pipeline
    vectorizer = TfidfVectorizer(
        max_features=1000,
        ngram_range=(1, 2),
        lowercase=True,
        stop_words='english'
    )

    classifier = LogisticRegression(
        max_iter=1000,
        C=1.0,
        random_state=42
    )

    # Train
    X_train_vec = vectorizer.fit_transform(X_train)
    X_test_vec = vectorizer.transform(X_test)

    classifier.fit(X_train_vec, y_train)

    # Evaluate
    y_pred = classifier.predict(X_test_vec)
    accuracy = accuracy_score(y_test, y_pred)

    print(f"\n✅ Model Accuracy: {accuracy:.2%}")
    print("\nClassification Report:")
    print(classification_report(y_test, y_pred))

    # Convert to CoreML
    print(f"\n🔄 Converting to CoreML...")

    # Create sklearn pipeline
    pipeline = Pipeline([
        ('vectorizer', vectorizer),
        ('classifier', classifier)
    ])

    # Convert using coremltools
    # Note: For text classification, you may need to use custom conversion
    # This is a simplified example - actual conversion may require
    # using coremltools.converters.sklearn or Create ML

    model_name = f"{dataset_name.capitalize()}Classifier"

    # For text models, you typically need to:
    # 1. Save sklearn model
    # 2. Create CoreML model with NLModel or custom conversion
    # 3. Or use Create ML for simpler workflow

    print(f"""
    ⚠️  MANUAL STEP REQUIRED:
    To complete CoreML conversion:

    Option 1 - Use Create ML (Recommended):
    1. Open Create ML app on macOS
    2. Create new Text Classifier project
    3. Import datasets/{dataset_name}_dataset.csv
    4. Train model with default settings
    5. Export as {model_name}.mlmodel

    Option 2 - Manual coremltools conversion:
    1. Use the saved sklearn model below
    2. Create custom CoreML converter
    3. See: https://coremltools.readme.io/docs/text-classifier
    """)

    # Save sklearn model for manual conversion
    import pickle
    with open(f'{model_name}_sklearn.pkl', 'wb') as f:
        pickle.dump(pipeline, f)

    print(f"\n💾 Saved sklearn model to {model_name}_sklearn.pkl")
    print(f"✅ Training complete for {dataset_name}!")

    return accuracy

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python train_template.py <dataset_name>")
        print("Example: python train_template.py horror")
        sys.exit(1)

    dataset_name = sys.argv[1]
    accuracy = train_model(dataset_name)

    if accuracy < 0.80:
        print(f"\n⚠️  WARNING: Accuracy {accuracy:.2%} is below 80% target!")
        print("Consider: (1) Adding more training data, (2) Adjusting model params, (3) Data quality review")
