#!/bin/bash

# Docker build script for ONT Tools Pipeline
# Usage: 
#   ./build_docker.sh          # Auto-increment version
#   ./build_docker.sh 3.5      # Specific version (without 'v' prefix)

# Set variables
DOCKER_USERNAME="sahuno"
IMAGE_NAME="onttools"
VERSION=${1:-}
TAG_VERSION=""
TAG_LATEST="${DOCKER_USERNAME}/${IMAGE_NAME}:latest"

# Determine version tag
if [ -n "$VERSION" ]; then
    # Manual version specified
    TAG_VERSION="${DOCKER_USERNAME}/${IMAGE_NAME}:v${VERSION}"
else
    # Auto-detect next version
    LATEST_TAG=$(git tag -l "v*" | sort -V | tail -n 1)
    if [ -z "$LATEST_TAG" ]; then
        # No existing tags, start with v3.0
        TAG_VERSION="${DOCKER_USERNAME}/${IMAGE_NAME}:v3.0"
    else
        # Extract and increment version
        MAJOR=$(echo $LATEST_TAG | cut -d. -f1 | sed 's/v//')
        MINOR=$(echo $LATEST_TAG | cut -d. -f2)
        MINOR=$((MINOR + 1))
        TAG_VERSION="${DOCKER_USERNAME}/${IMAGE_NAME}:v${MAJOR}.${MINOR}"
    fi
fi

echo "Building Docker images:"
echo "  - ${TAG_LATEST}"
echo "  - ${TAG_VERSION}"

echo "Building Docker images:"
echo "  - ${TAG_LATEST}"
echo "  - ${TAG_VERSION}"

# Build the Docker image
docker build -t ${TAG_VERSION} .

if [ $? -eq 0 ]; then
    echo "Build successful!"
    
    # Tag as latest
    docker tag ${TAG_VERSION} ${TAG_LATEST}
    
    echo ""
    echo "To push to Docker Hub, run:"
    echo "docker push ${TAG_VERSION}"
    echo "docker push ${TAG_LATEST}"
    echo ""
    echo "Or push both at once:"
    echo "docker push ${TAG_VERSION} && docker push ${TAG_LATEST}"
    echo ""
    echo "To run the container:"
    echo "docker run --gpus all -it -v \$(pwd):/data ${TAG_LATEST}"
    echo ""
    echo "For SLURM HPC usage with Singularity:"
    echo "singularity pull docker://${TAG_VERSION}"
else
    echo "Build failed!"
    exit 1
fi
