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
    ffmpeg libopenexr-dev libxi-dev ${comment# ngp} \
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
    && sh ~/.bashrc

# # install conda
# RUN \
#     sh -c "echo 'export CONDA_DIR=/opt/conda' >> /etc/profile" \
#     sh -c "echo 'export CONDA_ROOT=/opt/conda' >> /etc/profile" \
#     sh -c "echo 'export PATH=$CONDA_DIR/bin:$PATH' >> /etc/profile" \
#     source /etc/profile \
#     CONDA_MIRROR=https://github.com/conda-forge/miniforge/releases/latest/download

# # Miniforge installer
# RUN \
#     miniforge_arch=$(uname -m) && \
#     miniforge_installer="Mambaforge-Linux-${miniforge_arch}.sh" && \
#     wget --quiet "${CONDA_MIRROR}/${miniforge_installer}" && \
#     /bin/bash "${miniforge_installer}" -f -b -p "${CONDA_DIR}" && \
#     rm "${miniforge_installer}" && \
#     /opt/conda/bin/conda init \
#     source ~/.bashrc

# boost path
RUN mkdir /include && ln -s /usr/include/boost /include/boost

# build content path
RUN mkdir /content
WORKDIR /content

# ceres-solver & compile
RUN \
    git clone https://ceres-solver.googlesource.com/ceres-solver \
    && cd ceres-solver \
    && git checkout ${CERES_SOLVER_VERSION} \
    && mkdir build \
    && cd build \
    && cmake .. -DBUILD_TESTING=OFF -DBUILD_EXAMPLES=OFF \
    && make -j \
    && make install

# colmap & compile
RUN \
    git clone https://github.com/colmap/colmap \
    && cd colmap \
    && git checkout ${COLMAP_VERSION} \
    && mkdir build \
    && cd build \
    && cmake .. ${comment# -DCUDA_NVCC_FLAGS="--std c++17" -DCMAKE_CXX_FLAGS="-std=c++17"} \
    && make -j ${comment# CXXFLAGS="-std=c++17"} \
    && make install

# instant-ngp
RUN \
    git clone --recursive https://github.com/NVlabs/instant-ngp.git \
    && cd instant-ngp \
    && pip install -r requirements.txt \
    && cmake . -B build \
    && cmake --build build --config RelWithDebInfo -j `nproc`
