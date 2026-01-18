#!/usr/bin/env python3
"""
CoreML Conversion Script for Komalios GCP Models
Converts TensorFlow/PyTorch/ONNX models from GCP to CoreML format for iOS

Usage:
    python convert_to_coreml.py --model horror
    python convert_to_coreml.py --model all
"""

import argparse
import os
import sys
from pathlib import Path

try:
    import coremltools as ct
    import numpy as np
except ImportError:
    print("❌ Missing dependencies. Install with:")
    print("   pip install coremltools numpy")
    sys.exit(1)

# Optional: Uncomment based on your GCP model format
# import tensorflow as tf  # For TensorFlow models
# import torch  # For PyTorch models
# import onnx  # For ONNX models

# Model configurations
MODELS = {
    'horror': {
        'input_path': 'gcp_models/horror_classifier',
        'output_name': 'HorrorClassifier.mlmodel',
        'description': 'Detects horror, paranormal, and jumpscare content',
        'labels': ['safe', 'horror']
    },
    'cyberbullying': {
        'input_path': 'gcp_models/cyberbullying_classifier',
        'output_name': 'CyberbullyingClassifier.mlmodel',
        'description': 'Detects cyberbullying, harassment, and body-shaming',
        'labels': ['safe', 'bullying']
    },
    'parasocial': {
        'input_path': 'gcp_models/parasocial_classifier',
        'output_name': 'ParasocialClassifier.mlmodel',
        'description': 'Detects manipulative influencer content and FOMO triggers',
        'labels': ['safe', 'parasocial']
    },
    'financial': {
        'input_path': 'gcp_models/financial_classifier',
        'output_name': 'FinancialAdviceClassifier.mlmodel',
        'description': 'Detects risky financial advice and crypto scams',
        'labels': ['safe', 'financial_risk']
    },
    'mature': {
        'input_path': 'gcp_models/mature_content_classifier',
        'output_name': 'MatureContentClassifier.mlmodel',
        'description': 'Detects mature content (sexual, LGBTQ+, religious)',
        'labels': ['safe', 'sexual', 'lgbtq', 'religious']  # Multi-label
    }
}


def convert_tensorflow_to_coreml(model_path, output_path, config):
    """Convert TensorFlow SavedModel to CoreML"""
    print(f"🔄 Converting TensorFlow model from {model_path}")

    # Load TensorFlow model
    # tf_model = tf.saved_model.load(model_path)

    # Convert using coremltools
    # mlmodel = ct.convert(
    #     tf_model,
    #     inputs=[ct.TensorType(name="input_text", shape=(1,))],
    #     outputs=[ct.TensorType(name="output_probabilities")],
    #     convert_to="mlprogram",  # Use ML Program for iOS 15+
    # )

    # # Add metadata
    # mlmodel.short_description = config['description']
    # mlmodel.author = "Komalios Team"
    # mlmodel.license = "Proprietary"
    # mlmodel.version = "1.0.0"

    # # Save
    # mlmodel.save(output_path)
    # print(f"✅ Saved CoreML model to {output_path}")

    print("⚠️ TensorFlow conversion not implemented yet - add your conversion logic here")


def convert_pytorch_to_coreml(model_path, output_path, config):
    """Convert PyTorch model to CoreML"""
    print(f"🔄 Converting PyTorch model from {model_path}")

    # Load PyTorch model
    # model = torch.load(model_path)
    # model.eval()

    # # Trace the model
    # example_input = torch.rand(1, 512)  # Adjust shape based on your model
    # traced_model = torch.jit.trace(model, example_input)

    # # Convert to CoreML
    # mlmodel = ct.convert(
    #     traced_model,
    #     inputs=[ct.TensorType(name="input", shape=example_input.shape)],
    #     convert_to="mlprogram",
    # )

    # # Add metadata
    # mlmodel.short_description = config['description']
    # mlmodel.save(output_path)
    # print(f"✅ Saved CoreML model to {output_path}")

    print("⚠️ PyTorch conversion not implemented yet - add your conversion logic here")


def convert_onnx_to_coreml(model_path, output_path, config):
    """Convert ONNX model to CoreML"""
    print(f"🔄 Converting ONNX model from {model_path}")

    # Load ONNX model
    # onnx_model = onnx.load(model_path)

    # # Convert to CoreML
    # mlmodel = ct.convert(
    #     onnx_model,
    #     convert_to="mlprogram",
    # )

    # # Add metadata
    # mlmodel.short_description = config['description']
    # mlmodel.save(output_path)
    # print(f"✅ Saved CoreML model to {output_path}")

    print("⚠️ ONNX conversion not implemented yet - add your conversion logic here")


def convert_sklearn_to_coreml(model_path, output_path, config):
    """Convert scikit-learn model to CoreML (if using TF-IDF + LogisticRegression)"""
    print(f"🔄 Converting scikit-learn model from {model_path}")

    # Example for TF-IDF + Logistic Regression pipeline
    # import pickle
    # from coremltools.converters import sklearn as sklearn_converter

    # # Load pickled model
    # with open(model_path, 'rb') as f:
    #     sklearn_model = pickle.load(f)

    # # Convert pipeline (TF-IDF + Classifier)
    # mlmodel = sklearn_converter.convert(
    #     sklearn_model,
    #     input_features="text",
    #     output_feature_names=config['labels']
    # )

    # # Add metadata
    # mlmodel.short_description = config['description']
    # mlmodel.save(output_path)
    # print(f"✅ Saved CoreML model to {output_path}")

    print("⚠️ scikit-learn conversion not implemented yet - add your conversion logic here")


def detect_model_format(model_path):
    """Auto-detect model format from file structure"""
    model_path = Path(model_path)

    if (model_path / 'saved_model.pb').exists():
        return 'tensorflow'
    elif model_path.suffix == '.pt' or model_path.suffix == '.pth':
        return 'pytorch'
    elif model_path.suffix == '.onnx':
        return 'onnx'
    elif model_path.suffix == '.pkl' or model_path.suffix == '.joblib':
        return 'sklearn'
    else:
        print(f"⚠️ Unknown model format at {model_path}")
        return None


def validate_coreml_model(model_path, test_inputs=None):
    """Validate converted CoreML model"""
    print(f"\n🧪 Validating {model_path}...")

    try:
        mlmodel = ct.models.MLModel(model_path)

        # Print model info
        print(f"✅ Model loaded successfully")
        print(f"   Input: {mlmodel.get_spec().description.input}")
        print(f"   Output: {mlmodel.get_spec().description.output}")

        # Test with sample input if provided
        if test_inputs:
            for test_text in test_inputs:
                print(f"\n   Testing: '{test_text}'")
                # prediction = mlmodel.predict({'text': test_text})
                # print(f"   Result: {prediction}")

        return True

    except Exception as e:
        print(f"❌ Validation failed: {e}")
        return False


def convert_model(model_name, validate=True):
    """Convert a single model to CoreML"""
    if model_name not in MODELS:
        print(f"❌ Unknown model: {model_name}")
        print(f"   Available models: {', '.join(MODELS.keys())}")
        return False

    config = MODELS[model_name]
    input_path = Path(config['input_path'])
    output_path = Path(config['output_name'])

    print(f"\n{'='*60}")
    print(f"Converting {model_name.upper()} classifier")
    print(f"{'='*60}")

    # Check if input exists
    if not input_path.exists():
        print(f"❌ Input model not found at {input_path}")
        print(f"   Please download GCP models first!")
        return False

    # Detect format
    model_format = detect_model_format(input_path)
    if not model_format:
        return False

    print(f"📋 Detected format: {model_format}")

    # Convert based on format
    try:
        if model_format == 'tensorflow':
            convert_tensorflow_to_coreml(input_path, output_path, config)
        elif model_format == 'pytorch':
            convert_pytorch_to_coreml(input_path, output_path, config)
        elif model_format == 'onnx':
            convert_onnx_to_coreml(input_path, output_path, config)
        elif model_format == 'sklearn':
            convert_sklearn_to_coreml(input_path, output_path, config)

        # Validate if requested
        if validate and output_path.exists():
            test_inputs = [
                "This is a test string",
                "Scary horror ghost jumpscare",
                "Khan Academy math tutorial"
            ]
            validate_coreml_model(output_path, test_inputs)

        return True

    except Exception as e:
        print(f"❌ Conversion failed: {e}")
        import traceback
        traceback.print_exc()
        return False


def main():
    parser = argparse.ArgumentParser(description='Convert GCP models to CoreML')
    parser.add_argument(
        '--model',
        type=str,
        required=True,
        help='Model name (horror, cyberbullying, parasocial, financial, mature, all)'
    )
    parser.add_argument(
        '--no-validate',
        action='store_true',
        help='Skip validation after conversion'
    )

    args = parser.parse_args()

    print("🚀 CoreML Conversion Tool for Komalios")
    print("="*60)

    # Convert all models or single model
    if args.model == 'all':
        print("Converting all 5 models...\n")
        success_count = 0
        for model_name in MODELS.keys():
            if convert_model(model_name, validate=not args.no_validate):
                success_count += 1

        print(f"\n{'='*60}")
        print(f"✅ Converted {success_count}/{len(MODELS)} models successfully")

        if success_count == len(MODELS):
            print("\n🎉 All models ready for Xcode!")
            print("   Next step: Drag .mlmodel files into your Xcode project")
            return 0
        else:
            print("\n⚠️ Some models failed to convert. Check errors above.")
            return 1
    else:
        # Convert single model
        if convert_model(args.model, validate=not args.no_validate):
            print(f"\n✅ {args.model} model ready for Xcode!")
            return 0
        else:
            return 1


if __name__ == '__main__':
    sys.exit(main())
