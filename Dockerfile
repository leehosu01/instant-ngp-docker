FROM nvidia/cuda:11.6.2-cudnn8-devel-ubuntu20.04

ENV COLMAP_VERSION=3.7
ENV CMAKE_VERSION=3.21.0
ENV PYTHON_VERSION=3.10.5
ENV CERES_SOLVER_VERSION=2.1.0
ENV comment=

# install GCC & colmap requirements
RUN export DEBIAN_FRONTEND=noninteractive \
    && apt -y update --no-install-recommends \
    && apt -y install --no-install-recommends \
    gcc-9 g++-9 wget git build-essential \
    libatlas-base-dev \
    libboost-program-options-dev \
    libboost-filesystem-dev \
    libboost-graph-dev \
    libboost-regex-dev \
    libboost-system-dev \
    libboost-test-dev \
    libeigen3-dev \
    libsuitesparse-dev \
    libmetis-dev \
    libfreeimage-dev \
    libgoogle-glog-dev \
    libgflags-dev \
    libglew-dev \
    qtbase5-dev \
    libqt5opengl5-dev \
    libcgal-dev \
    libcgal-qt5-dev \
    libffi-dev libssl-dev zlib1g-dev ${comment# python} \
    libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm ${comment# python} \
    libncurses5-dev libncursesw5-dev xz-utils tk-dev ${comment# python} \
    ffmpeg unzip libopenexr-dev libxi-dev ${comment# ngp} \
    libglfw3-dev libomp-dev libxinerama-dev libxcursor-dev ${comment# ngp} \
    xorg-dev libglu1-mesa-dev -y ${comment# tiny-cuda-nn} \
    && apt autoremove -y \
    && apt clean -y

# setup GCC
RUN \
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-9 20 \
    && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-9 20 \
    && update-alternatives --install /usr/bin/cc cc /usr/bin/gcc 30 \
    && update-alternatives --set cc /usr/bin/gcc \
    && update-alternatives --install /usr/bin/c++ c++ /usr/bin/g++ 30 \
    && update-alternatives --set c++ /usr/bin/g++

WORKDIR /tmp

# install python
RUN \
    wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz \
    && tar xzf Python-${PYTHON_VERSION}.tgz \
    && cd ./Python-${PYTHON_VERSION} \
    && ./configure --enable-optimizations \
    && make -j \
    && make install \
    && python3 -m pip install --upgrade pip setuptools wheel cmake \
    && echo "alias pip=pip3" >> ~/.bashrc \
    && sh ~/.bashrc \
    && rm -rf /tmp/*

# boost path
RUN mkdir /include && ln -s /usr/include/boost /include/boost

# ceres-solver & compile
RUN \
    git clone https://ceres-solver.googlesource.com/ceres-solver \
    && cd ceres-solver \
    && git checkout ${CERES_SOLVER_VERSION} \
    && mkdir build \
    && cd build \
    && cmake .. -DBUILD_TESTING=OFF -DBUILD_EXAMPLES=OFF \
    && make -j \
    && make install \
    && rm -rf /tmp/*

# colmap & compile
RUN \
    git clone https://github.com/colmap/colmap \
    && cd colmap \
    && git checkout ${COLMAP_VERSION} \
    && mkdir build \
    && cd build \
    && cmake .. ${comment# -DCUDA_NVCC_FLAGS="--std c++17" -DCMAKE_CXX_FLAGS="-std=c++17"} \
    && make -j ${comment# CXXFLAGS="-std=c++17"} \
    && make install \
    && rm -rf /tmp/*

# build content path
RUN mkdir /content
WORKDIR /content

# instant-ngp
RUN \
    git clone --recursive https://github.com/NVlabs/instant-ngp.git \
    && cd instant-ngp \
    && pip install -r requirements.txt \
    && cmake . -B build \
    && cmake --build build --config RelWithDebInfo -j `nproc`

COPY execute.ipynb execute.ipynb

# workspace requirements
COPY External/ml-workspace/scripts/clean-layer.sh  /usr/bin/clean-layer.sh
COPY External/ml-workspace/scripts/fix-permissions.sh  /usr/bin/fix-permissions.sh

# script that we will use to correct permissions after running certain commands
RUN \
    chmod a+rwx /usr/bin/clean-layer.sh && \
    chmod a+rwx /usr/bin/fix-permissions.sh

COPY External/ml-workspace/branding/logo.png /tmp/logo.png
COPY External/ml-workspace/branding/favicon.ico /tmp/favicon.ico

# Install Python package from environment.yml
RUN pip install jupyter


RUN /bin/bash -c 'cp /tmp/logo.png $(python3 -c "import sys; print(sys.path[-1])")/notebook/static/base/images/logo.png'
RUN /bin/bash -c 'cp /tmp/favicon.ico $(python3 -c "import sys; print(sys.path[-1])")/notebook/static/base/images/favicon.ico'
RUN /bin/bash -c 'cp /tmp/favicon.ico $(python3 -c "import sys; print(sys.path[-1])")/notebook/static/favicon.ico'

## Install Visual Studio Code Server
RUN curl -fsSL https://code-server.dev/install.sh | sh && clean-layer.sh

## Install ttyd. (Not recommended to edit)
RUN \
    wget https://github.com/tsl0922/ttyd/archive/refs/tags/1.6.2.zip \
    && unzip 1.6.2.zip
RUN apt update && apt -y install libuv1-dev libjson-c-dev libwebsockets-dev -y

RUN \
    cd ttyd-1.6.2 \
    && mkdir build \
    && cd build \
    && cmake .. \
    && make \
    && make install

# Make folders
ENV WORKSPACE_HOME="/workspace"
RUN \
    if [ -e $WORKSPACE_HOME ] ; then \
    chmod a+rwx $WORKSPACE_HOME; \
    else \
    mkdir $WORKSPACE_HOME && chmod a+rwx $WORKSPACE_HOME; \
    fi
ENV HOME=$WORKSPACE_HOME
WORKDIR $WORKSPACE_HOME
### Start Ainize Worksapce ###
COPY External/ml-workspace/start.sh /scripts/start.sh
RUN ["chmod", "+x", "/scripts/start.sh"]
CMD sh -c "mv /content/instant-ngp/ \"$WORKSPACE_HOME\"; mv /content/execute.ipynb \"$WORKSPACE_HOME\"; /scripts/start.sh"