#!/bin/bash
# Setup environment for Komal Emoji Avatar Engine

set -e

echo "Setting up Komal Avatar Engine environment..."

# Check Python version
python_version=$(python3 --version 2>&1 | cut -d' ' -f2 | cut -d'.' -f1,2)
echo "Python version: $python_version"

# Create virtual environment
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate
source venv/bin/activate

# Install Python dependencies
echo "Installing Python dependencies..."
pip install --upgrade pip
pip install pillow numpy imageio

# Optional: Install for compute-heavy mode
if [ "$1" == "--full" ]; then
    echo "Installing full dependencies..."
    pip install scipy numba
fi

# Create output directories
mkdir -p outputs batch_outputs thumbnails

# Check Node.js for web customizer
if command -v node &> /dev/null; then
    echo "Node.js found: $(node --version)"

    # Install web customizer dependencies
    if [ -d "emoji_web_customizer" ]; then
        echo "Installing web customizer dependencies..."
        cd emoji_web_customizer && npm install && cd ..
    fi
else
    echo "Warning: Node.js not found. Web customizer will not work."
fi

# Check Expo for mobile
if command -v npx &> /dev/null; then
    if [ -d "emoji_mobile_customizer" ]; then
        echo "Installing mobile customizer dependencies..."
        cd emoji_mobile_customizer && npm install && cd ..
    fi
fi

echo ""
echo "Setup complete!"
echo ""
echo "Usage:"
echo "  source venv/bin/activate"
echo "  python emoji_avatar_engine.py --emoji smile --seconds 3 --out my_avatar.mp4"
echo ""
echo "Web customizer:"
echo "  cd emoji_web_customizer && npm run dev"
echo ""
