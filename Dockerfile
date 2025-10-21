# Multi-stage build for efficient image size
# Base image with CUDA support for GPU acceleration
FROM nvidia/cuda:12.3.1-devel-ubuntu22.04 AS builder

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/root/.cargo/bin:${PATH}"
ENV CUDA_HOME=/usr/local/cuda
ENV PATH="${CUDA_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    curl \
    git \
    wget \
    zlib1g-dev \
    libbz2-dev \
    liblzma-dev \
    libncurses5-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libffi-dev \
    libhdf5-dev \
    hdf5-tools \
    autoconf \
    automake \
    libtool \
    pkg-config \
    software-properties-common \
    ca-certificates \
    gnupg \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Install Python 3.12
RUN add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y \
      python3.12 \
      python3.12-dev && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 && \
    update-alternatives --install /usr/bin/python  python  /usr/bin/python3.12 1 && \
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3.12 && \
    python3.12 -m pip install --no-cache-dir --upgrade pip setuptools wheel && \
    rm -rf /var/lib/apt/lists/*


# Install Rust (required for modkit)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Create working directory
WORKDIR /opt

#RUN cargo install modkit; do this now rather than in final stage.
RUN cargo install --git https://github.com/nanoporetech/modkit.git

# Install samtools, bcftools, htslib
RUN wget https://github.com/samtools/samtools/releases/download/1.22/samtools-1.22.tar.bz2 && \
    tar -xjf samtools-1.22.tar.bz2 && \
    cd samtools-1.22 && \
    ./configure && make && make install && \
    cd .. && rm -rf samtools-1.22*

RUN wget https://github.com/samtools/bcftools/releases/download/1.22/bcftools-1.22.tar.bz2 && \
    tar -xjf bcftools-1.22.tar.bz2 && \
    cd bcftools-1.22 && \
    ./configure && make && make install && \
    cd .. && rm -rf bcftools-1.22*

RUN wget https://github.com/samtools/htslib/releases/download/1.22/htslib-1.22.tar.bz2 && \
    tar -xjf htslib-1.22.tar.bz2 && \
    cd htslib-1.22 && \
    ./configure && make && make install && \
    cd .. && rm -rf htslib-1.22*

# tabix and bgzip are included with htslib installation

# Install bedtools
RUN wget https://github.com/arq5x/bedtools2/releases/download/v2.31.1/bedtools-2.31.1.tar.gz && \
    tar -zxf bedtools-2.31.1.tar.gz && \
    cd bedtools2 && \
    make && \
    cp bin/* /usr/local/bin/ && \
    cd .. && rm -rf bedtools*

# Install Sniffles
RUN git clone --depth 1 https://github.com/fritzsedlazeck/Sniffles.git && \
    cd Sniffles && \
    pip3 install -e . && \
    cd ..

# Install mosdepth
RUN wget https://github.com/brentp/mosdepth/releases/download/v0.3.11/mosdepth && \
    chmod +x mosdepth && \
    mv mosdepth /usr/local/bin/

# Install UCSC utilities
RUN mkdir -p /usr/local/ucsc && \
    cd /usr/local/ucsc && \
    wget -q http://hgdownload.soe.ucsc.edu/admin/exe/linux.x86_64/bedGraphToBigWig && \
    wget -q http://hgdownload.soe.ucsc.edu/admin/exe/linux.x86_64/bigWigToBedGraph && \
    wget -q http://hgdownload.soe.ucsc.edu/admin/exe/linux.x86_64/wigToBigWig && \
    wget -q http://hgdownload.soe.ucsc.edu/admin/exe/linux.x86_64/bedToBigBed && \
    wget -q http://hgdownload.soe.ucsc.edu/admin/exe/linux.x86_64/bigBedToBed && \
    wget -q --tries=3 --timeout=60 https://hgdownload.soe.ucsc.edu/admin/exe/linux.x86_64/liftOver && \
    wget -q http://hgdownload.soe.ucsc.edu/admin/exe/linux.x86_64/fetchChromSizes && \
    chmod +x * && \
    cp * /usr/local/bin/

# Final stage
FROM nvidia/cuda:12.3.1-runtime-ubuntu22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/root/.cargo/bin:${PATH}"
ENV CUDA_HOME=/usr/local/cuda
ENV PATH="${CUDA_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}"

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    wget \
    zlib1g \
    libbz2-1.0 \
    liblzma5 \
    libncurses5 \
    libcurl4 \
    libssl3 \
    libhdf5-103-1 \
    hdf5-tools \
    software-properties-common \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Python 3.12
# Install Python 3.12
RUN add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y python3.12 python3.12-dev python3-pip && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3.12 1 && \
    rm -rf /var/lib/apt/lists/*
#RUN add-apt-repository ppa:deadsnakes/ppa && \
#    apt-get update && \
#    apt-get install -y python3.12 python3-pip && \
#    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 && \
#    update-alternatives --install /usr/bin/python python /usr/bin/python3.12 1 && \
#    rm -rf /var/lib/apt/lists/*

# Install pip for Python 3.12
RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python3.12

# Copy from builder
COPY --from=builder /usr/local /usr/local
#COPY --from=builder /root/.cargo /root/.cargo
COPY --from=builder /opt/Sniffles /opt/Sniffles
COPY --from=builder /root/.cargo/bin/modkit /usr/local/bin/

# Quick sanity-check: make sure modkit is on PATH; tricky & it misses many times
RUN modkit --version
# Install Rust (required for runtime)
#RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

WORKDIR /opt

# Install dorado (latest version)
RUN wget https://cdn.oxfordnanoportal.com/software/analysis/dorado-1.2.0-linux-x64.tar.gz && \
    tar -xzf dorado-1.2.0-linux-x64.tar.gz && \
    mv dorado-1.2.0-linux-x64/bin/* /usr/local/bin/ && \
    mv dorado-1.2.0-linux-x64/lib/* /usr/local/lib/ && \
    rm -rf dorado* && \
    ldconfig

# Install pod5
RUN pip3 install pod5

# Install modkit
#RUN cargo install modkit
#RUN cargo install --git https://github.com/nanoporetech/modkit.git

# Install longphase
# Install longphase
RUN wget https://github.com/twolinin/longphase/releases/download/v1.7.3/longphase_linux-x64.tar.xz && \
    tar -xJf longphase_linux-x64.tar.xz && \
    mv longphase_linux-x64 /usr/local/bin/longphase && \
    chmod +x /usr/local/bin/longphase && \
    rm -rf longphase_linux-x64.tar.xz
#RUN wget https://github.com/twolinin/longphase/releases/download/v1.7.3/longphase_linux-x64.tar.xz && \
#    tar -xJf longphase_linux-x64.tar.xz && \
#    mv longphase_linux-x64/longphase /usr/local/bin/ && \
#    rm -rf longphase*

# Install whatshap
RUN pip3 install whatshap

# Install methylartist
RUN git clone https://github.com/adamewing/methylartist.git && \
    cd methylartist && \
    pip3 install -e . && \
    cd ..

# Install MultiQC
RUN pip3 install multiqc

# Install deepTools
RUN pip3 install deeptools

# Install igv-reports
RUN pip3 install igv-reports

# Copy requirements file, test script, and example analysis script
COPY requirements.txt /opt/requirements.txt
COPY test_installation.sh /usr/local/bin/test_installation
#COPY example_methylation_analysis.py /opt/example_methylation_analysis.py
RUN chmod +x /usr/local/bin/test_installation

# Install Python packages
RUN pip3 install -r /opt/requirements.txt

# Clean up
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create working directory for analysis
RUN mkdir -p /data /results

WORKDIR /data

# Set default command
CMD ["/bin/bash"]
