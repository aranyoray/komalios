#!/bin/bash
# entrypoint.sh — docker container entrypoint
set -e

echo "komal container starting..."
echo "cuda version: $(nvcc --version | grep release)"
echo "python version: $(python3 --version)"
echo "torch version: $(python3 -c 'import torch; print(torch.__version__)')"

# check gpu availability
python3 -c "import torch; print(f'gpus available: {torch.cuda.device_count()}')"

# run command or default to bash
exec "$@"
