#!/bin/bash

# Docker build script for Nanopore Methylation Analysis Pipeline
# Usage: ./build_docker.sh [tag]

# Set variables
DOCKER_USERNAME="sahuno"
IMAGE_NAME="nanopore-methylation"
TAG=${1:-latest}
FULL_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}:${TAG}"

echo "Building Docker image: ${FULL_IMAGE_NAME}"

# Build the Docker image
docker build -t ${FULL_IMAGE_NAME} .

if [ $? -eq 0 ]; then
    echo "Build successful!"
    echo ""
    echo "To push to Docker Hub, run:"
    echo "docker push ${FULL_IMAGE_NAME}"
    echo ""
    echo "To run the container:"
    echo "docker run --gpus all -it -v \$(pwd):/data ${FULL_IMAGE_NAME}"
    echo ""
    echo "For SLURM HPC usage with Singularity:"
    echo "singularity pull docker://${FULL_IMAGE_NAME}"
else
    echo "Build failed!"
    exit 1
fi
