# Base image
FROM nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04

# Set environment variables for NVIDIA and PyTorch
ENV NVIDIA_VISIBLE_DEVICES=all
ENV TORCH_CUDA_ARCH_LIST="7.0 7.5 8.0 8.6"

# Install system dependencies, including FFmpeg
# The base image should have most build tools. We'll add specific ones if needed.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    wget \
    tar \
    xz-utils \
    fonts-liberation \
    fontconfig \
    python3-pip \
    git \
    build-essential \
    pkg-config \
    # FFmpeg build dependencies (subset from original, plus CUDA related)
    yasm \
    nasm \
    libssl-dev \
    libvpx-dev \
    libx264-dev \
    libx265-dev \
    libnuma-dev \
    libmp3lame-dev \
    libopus-dev \
    libvorbis-dev \
    libtheora-dev \
    libspeex-dev \
    libfreetype6-dev \
    libfontconfig1-dev \
    libgnutls28-dev \
    libaom-dev \
    libdav1d-dev \
    # librav1e-dev and libsvtav1-dev might require rust/newer meson, keeping them out for now to simplify
    libzimg-dev \
    libwebp-dev \
    autoconf \
    automake \
    libtool \
    libfribidi-dev \
    libharfbuzz-dev \
    # Add any other essential packages that might be missing and are not for compiling from source
    && rm -rf /var/lib/apt/lists/*

# Build and install FFmpeg with NVIDIA GPU support and other required features
RUN git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg && \
    cd ffmpeg && \
    git checkout n7.0.2 && \
    # PKG_CONFIG_PATH might need /usr/local/cuda/lib64/pkgconfig if CUDA libs provide .pc files
    # However, --extra-cflags and --extra-ldflags are more direct for CUDA.
    ./configure --prefix=/usr/local \
        --enable-gpl \
        --enable-nonfree \
        --enable-pthreads \
        # CUDA specific flags
        --enable-nvenc \
        --enable-nvdec \
        --enable-cuda-llvm \
        --enable-cuvid \
        --enable-cuda \
        --extra-cflags="-I/usr/local/cuda/include" \
        --extra-ldflags="-L/usr/local/cuda/lib64" \
        # Existing codec and feature flags (adjusted)
        --enable-libaom \
        --enable-libdav1d \
        --enable-libzimg \
        --enable-libx264 \
        --enable-libx265 \
        --enable-libvpx \
        --enable-libwebp \
        --enable-libmp3lame \
        --enable-libopus \
        --enable-libvorbis \
        --enable-libtheora \
        --enable-libspeex \
        --enable-libass \
        --enable-libfreetype \
        --enable-libharfbuzz \
        --enable-fontconfig \
        --enable-gnutls \
        # --enable-libsrt # srt-gnutls-dev package would be needed
        --enable-filter=drawtext \
    && make -j$(nproc) && \
    make install && \
    cd .. && rm -rf ffmpeg && \
    ldconfig # Refresh shared library cache

# Copy fonts into the custom fonts directory
COPY ./fonts /usr/share/fonts/custom

# Rebuild the font cache so that fontconfig can see the custom fonts
RUN fc-cache -f -v

# Set work directory
WORKDIR /app

# Set environment variable for Whisper cache
ENV WHISPER_CACHE_DIR="/app/whisper_cache"

# Create cache directory (no need for chown here yet)
RUN mkdir -p ${WHISPER_CACHE_DIR} 

# Copy the requirements file first to optimize caching
COPY requirements.txt .

# Install Python dependencies, upgrade pip 
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt && \
    pip install openai-whisper && \
    pip install jsonschema && \
    pip install yt-dlp

# Create the appuser 
RUN useradd -m appuser 

# Give appuser ownership of the /app directory (including whisper_cache)
RUN chown appuser:appuser /app 

# Important: Switch to the appuser before downloading the model
USER appuser

RUN python -c "import os; print(os.environ.get('WHISPER_CACHE_DIR')); import whisper; whisper.load_model('base')"

# Copy the rest of the application code
COPY . .

# Expose the port the app runs on
EXPOSE 8080

# Set environment variables
ENV PYTHONUNBUFFERED=1

RUN echo '#!/bin/bash\n\
gunicorn --bind 0.0.0.0:8080 \
    --workers ${GUNICORN_WORKERS:-2} \
    --timeout ${GUNICORN_TIMEOUT:-300} \
    --worker-class sync \
    --keep-alive 80 \
    app:app' > /app/run_gunicorn.sh && \
    chmod +x /app/run_gunicorn.sh

# Run the shell script
CMD ["/app/run_gunicorn.sh"]
