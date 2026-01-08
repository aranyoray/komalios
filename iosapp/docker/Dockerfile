# docker/Dockerfile — CUDA base with ML dependencies for Komal
FROM nvidia/cuda:12.1-cudnn8-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# system deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.10 python3-pip python3.10-venv \
    ffmpeg libsm6 libxext6 libgl1-mesa-glx \
    libopencv-dev cmake build-essential \
    git wget curl vim htop \
    && rm -rf /var/lib/apt/lists/*

# python env
RUN python3 -m pip install --upgrade pip setuptools wheel

# ml dependencies (pin major versions, edit as needed)
RUN pip install --no-cache-dir \
    torch==2.2.0 torchvision==0.17.0 torchaudio==2.2.0 \
    --index-url https://download.pytorch.org/whl/cu121

RUN pip install --no-cache-dir \
    deepspeed==0.13.0 \
    fairscale==0.4.13 \
    transformers==4.38.0 \
    datasets==2.17.0 \
    accelerate==0.27.0 \
    wandb==0.16.0 \
    hydra-core==1.3.2 \
    submitit==1.5.1 \
    optuna==3.5.0 \
    ray[tune]==2.9.0 \
    opencv-python==4.9.0.80 \
    mediapipe==0.10.9 \
    dlib==19.24.2 \
    librosa==0.10.1 \
    soundfile==0.12.1 \
    pandas==2.2.0 \
    scikit-learn==1.4.0 \
    scipy==1.12.0 \
    matplotlib==3.8.0 \
    seaborn==0.13.0 \
    causal-learn==0.1.3.7 \
    flower==1.7.0 \
    opacus==1.4.0

WORKDIR /workspace/komal

COPY . /workspace/komal

RUN chmod +x /workspace/komal/entrypoint.sh

ENTRYPOINT ["/workspace/komal/entrypoint.sh"]
CMD ["bash"]
