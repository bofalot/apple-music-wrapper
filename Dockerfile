# ====== Build Stage ======
FROM ubuntu:latest AS builder

# Set working directory
WORKDIR /app

# Install dependencies
RUN apt update && apt install -y \
    aria2 unzip cmake ninja-build wget lsb-release clang-16 lld-16 lldb-16 \
    && rm -rf /var/lib/apt/lists/*

# Download and extract Android NDK r23b
RUN aria2c -o android-ndk-r23b-linux.zip https://dl.google.com/android/repository/android-ndk-r23b-linux.zip && \
    unzip -q android-ndk-r23b-linux.zip -d /opt && \
    rm android-ndk-r23b-linux.zip

# Set environment variables
ENV ANDROID_NDK_HOME=/opt/android-ndk-r23b
ENV PATH="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin:${PATH}"
ENV HOME=/opt

# Copy source code
COPY . /app

# Build the project
RUN mkdir -p build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake \
    -DANDROID_NDK=$ANDROID_NDK_HOME -DANDROID_ABI=x86_64 -DANDROID_PLATFORM=android-22 \
    -DANDROIDAPPMUSIC_LIB=/app/rootfs/system/lib64/libandroidappmusic.so \
    -DMEDIAPLATFORM_LIB=/app/rootfs/system/lib64/libmediaplatform.so \
    -DSTORESERVICESCORE_LIB=/app/rootfs/system/lib64/libstoreservicescore.so \
    -DCXX_SHARED_LIB=/app/rootfs/system/lib64/libc++_shared.so && \
    cmake --build .

# ====== Runtime Stage ======
FROM ubuntu:latest

# Set working directory
WORKDIR /app

# Install only runtime dependencies (minimal footprint)
RUN apt update && apt install -y \
    bash \
    && rm -rf /var/lib/apt/lists/*

# Copy built artifacts from the builder stage
COPY --from=builder /app/build /app/build
COPY --from=builder /app/wrapper /app/wrapper

# Copy source code
COPY . /app

# Set args environment variable
ENV args ""

# Expose necessary ports
EXPOSE 10020 20020

# Default command
CMD ["bash", "-c", "./wrapper ${args}"]
