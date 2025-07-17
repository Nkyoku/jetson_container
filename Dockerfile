# Based on https://github.com/atinfinity/l4t-ros2-docker
#      and https://catalog.ngc.nvidia.com/orgs/nvidia/containers/l4t-jetpack

FROM ros:jazzy-ros-base-noble

ARG DEBIAN_FRONTEND=noninteractive

ENV NVIDIA_DRIVER_CAPABILITIES=all
ENV NVIDIA_VISIBLE_DEVICES=all

# Install essential packages
RUN apt update && \
    apt install -qq -y --no-install-recommends \
        cmake \
        freeglut3-dev \
        git \
        git-lfs \
        gstreamer1.0-libav \
        gstreamer1.0-plugins-bad \
        gstreamer1.0-plugins-base \
        gstreamer1.0-plugins-good \
        gstreamer1.0-plugins-ugly \
        gstreamer1.0-tools \
        gstreamer1.0-x \
        libgles2 \
        libglu1-mesa-dev \
        libglvnd-dev \
        libgstreamer1.0-0 \
        libgstreamer-plugins-base1.0-dev \
        libgstrtspserver-1.0-0 \
        libjansson4 \
        libopencv-dev \
        libssl3 \
        libssl-dev \
        libvulkan1 \
        mesa-utils \
        python3 \
        python3-pip \
        python3-venv \
        ros-dev-tools \
        sudo \
        vulkan-tools \
        wget \
        && \
    apt-mark hold libopencv-dev && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*

# EGL
RUN echo "/usr/lib/aarch64-linux-gnu/tegra" >> /etc/ld.so.conf.d/nvidia-tegra.conf && \
    echo "/usr/lib/aarch64-linux-gnu/tegra-egl" >> /etc/ld.so.conf.d/nvidia-tegra.conf
RUN rm -rf /usr/share/glvnd/egl_vendor.d && \
    mkdir -p /usr/share/glvnd/egl_vendor.d/ && echo '\
{\
    "file_format_version" : "1.0.0",\
    "ICD" : {\
        "library_path" : "libEGL_nvidia.so.0"\
    }\
}' > /usr/share/glvnd/egl_vendor.d/10_nvidia.json
RUN mkdir -p /usr/share/egl/egl_external_platform.d/ && echo '\
{\
    "file_format_version" : "1.0.0",\
    "ICD" : {\
        "library_path" : "libnvidia-egl-wayland.so.1"\
    }\
}' > /usr/share/egl/egl_external_platform.d/nvidia_wayland.json

# Add Jetson repository
RUN wget -O /etc/apt/keyrings/jetson-ota-public.key https://gitlab.com/nvidia/container-images/l4t-base/-/raw/master/jetson-ota-public.key && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/jetson-ota-public.key] https://repo.download.nvidia.com/jetson/common r36.4 main" >> /etc/apt/sources.list.d/nvidia-l4t-apt-source.list && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/jetson-ota-public.key] https://repo.download.nvidia.com/jetson/t234 r36.4 main" >> /etc/apt/sources.list.d/nvidia-l4t-apt-source.list && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/jetson-ota-public.key] https://repo.download.nvidia.com/jetson/ffmpeg r36.4 main" >> /etc/apt/sources.list.d/nvidia-l4t-apt-source.list

# Install Jetson Multimedia API
RUN apt update && \
    apt download nvidia-l4t-jetson-multimedia-api && \
    dpkg-deb -R ./nvidia-l4t-jetson-multimedia-api_*_arm64.deb ./mm-api && \
    cp -r ./mm-api/usr/src/jetson_multimedia_api /usr/src/jetson_multimedia_api && \
    sed -i 's/sudo//' ./mm-api/DEBIAN/postinst && \
    ./mm-api/DEBIAN/postinst && \
    rm -rf ./nvidia-l4t-jetson-multimedia-api_*_arm64.deb ./mm-api

# Install fake packages to avoid Python version conflict
RUN --mount=type=bind,target=/tmp/python3-libnvinfer-dev.deb,source=python3-libnvinfer-dev_10.3.0.30-1+cuda12.5_all.deb \
    apt install /tmp/python3-libnvinfer-dev.deb

# Install CUDA, DeepStream etc.
RUN apt update && \
    apt install -qq -y --no-install-recommends \
        cuda \
        deepstream-7.1 \
        tensorrt \
        tensorrt-dev \
        vpi3-dev \
        && \
    apt clean && \
    ln -s /usr/lib/aarch64-linux-gnu/nvidia /usr/lib/aarch64-linux-gnu/tegra && \
    rm -rf /var/lib/apt/lists/*

ENV PATH=/usr/local/cuda/bin:$PATH
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

# Install libyaml-cpp.so.0.7 for DeepStream
RUN git clone --single-branch --depth 1 -b yaml-cpp-0.7.0 https://github.com/jbeder/yaml-cpp.git /tmp/yaml-cpp && \
    cmake -S /tmp/yaml-cpp -B /tmp/yaml-cpp/build -DYAML_BUILD_SHARED_LIBS=ON -DYAML_CPP_BUILD_TESTS=OFF && \
    make -C /tmp/yaml-cpp/build && \
    cp -a /tmp/yaml-cpp/build/libyaml-cpp.so.0.7* /usr/local/lib/ && \
    rm -rf /tmp/yaml-cpp && \
    ldconfig
