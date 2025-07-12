# Based on https://github.com/atinfinity/l4t-ros2-docker

FROM docker.io/arm64v8/ubuntu:24.04

ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all

ARG DEBIAN_FRONTEND=noninteractive
ARG UID=1000
ARG GID=1000
ENV USER=jetson
ENV HOME=/home/$USER

# Delete existing user
# https://askubuntu.com/questions/1513927/ubuntu-24-04-docker-images-now-includes-user-ubuntu-with-uid-gid-1000
RUN if getent passwd $UID; then \
      userdel -f $(getent passwd $UID | cut -d: -f1); \
    fi \
    && if getent group $GID; then \
      groupdel $(getent group $GID | cut -d: -f1); \
    fi

# Create user
RUN useradd -m $USER && \
    echo "$USER:$USER" | chpasswd && \
    usermod --shell /bin/bash $USER && \
    usermod -aG sudo $USER && \
    echo "$USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USER && \
    chmod 0440 /etc/sudoers.d/$USER && \
    usermod --uid $UID $USER && \
    groupmod --gid $GID $USER
RUN usermod -aG video $USER
USER $USER
WORKDIR $HOME
SHELL ["/bin/bash", "-l", "-c"]

RUN apt update && \
    apt install -qq -y --no-install-recommends \
        bash-completion \
        bc \
        build-essential \
        bzip2 \
        ca-certificates \
        cmake \
        command-not-found \
        curl \
        freeglut3-dev \
        git \
        gnupg2 \
        gstreamer1.0-alsa \
        gstreamer1.0-libav \
        gstreamer1.0-plugins-bad \
        gstreamer1.0-plugins-base \
        gstreamer1.0-plugins-good \
        gstreamer1.0-plugins-ugly \
        gstreamer1.0-tools \
        iproute2 \
        iputils-ping \
        kbd \
        kmod \
        language-pack-en-base \
        libapt-pkg-dev \
        libcanberra-gtk3-module \
        libgles2 \
        libglu1-mesa-dev \
        libglvnd-dev \
        libgtk-3-0 \
        libudev1 \
        libvulkan1 \
        mesa-utils \
        nano \
        python3 \
        python3-pip \
        sudo \
        udev \
        vulkan-tools \
        wget \
        && \
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

RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/jetson-ota-public.gpg] https://repo.download.nvidia.com/jetson/common r36.4 main" >> /etc/apt/sources.list.d/nvidia-l4t-apt-source.list && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/jetson-ota-public.gpg] https://repo.download.nvidia.com/jetson/t234 r36.4 main" >> /etc/apt/sources.list.d/nvidia-l4t-apt-source.list && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/jetson-ota-public.gpg] https://repo.download.nvidia.com/jetson/ffmpeg r36.4 main" >> /etc/apt/sources.list.d/nvidia-l4t-apt-source.list
RUN wget -O /etc/jetson-ota-public.key https://gitlab.com/nvidia/container-images/l4t-base/-/raw/master/jetson-ota-public.key && \
    cat /etc/jetson-ota-public.key | gpg --dearmor -o /usr/share/keyrings/jetson-ota-public.gpg

# Install CUDA, cuDNN, DeepStream etc.
RUN apt update && \
    apt install -qq -y --no-install-recommends \
        cuda \
        libcudnn9 \
        libcudnn9-dev \
        deepstream-7.1 \
        && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*

# Install libyaml-cpp.so.0.7 for DeepStream
RUN cd ~ && \
    git clone --single-branch --depth 1 -b yaml-cpp-0.7.0 https://github.com/jbeder/yaml-cpp.git && \
    mkdir -p yaml-cpp/build && \
    cd yaml-cpp/build && \
    cmake -DYAML_BUILD_SHARED_LIBS=ON -DYAML_CPP_BUILD_TESTS=OFF .. && \
    make && \
    cp libyaml-cpp.so.0.7 libyaml-cpp.so.0.7.0 /usr/local/lib/ && \
    cd ~ && \
    rm -rf yaml-cpp && \
    ldconfig

# install ROS2 Jazzy
RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null
RUN apt update && \
    apt install -qq -y --no-install-recommends \
        ros-jazzy-ros-base \
        ros-dev-tools \
        python3-colcon-common-extensions \
        python3-rosdep \
        && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*

RUN echo "export PATH=/usr/local/cuda/bin:$PATH" >> ~/.bashrc && \
    echo "export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH" >> ~/.bashrc

# initialize rosdep
RUN sudo rosdep init && \
    rosdep update

RUN echo "source /opt/ros/jazzy/setup.bash" >> ~/.bashrc
