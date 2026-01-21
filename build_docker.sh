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

# Function to get latest version from Docker Hub
get_dockerhub_version() {
    local response=$(curl -s --max-time 10 "https://hub.docker.com/v2/repositories/${DOCKER_USERNAME}/${IMAGE_NAME}/tags/?page_size=100" 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        # Parse JSON to get latest v*.* tag
        echo "$response" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    tags = [t['name'] for t in data.get('results', []) if t['name'].startswith('v') and '.' in t['name']]
    if tags:
        # Sort by version number
        sorted_tags = sorted(tags, key=lambda x: [int(n) for n in x.lstrip('v').split('.')])
        print(sorted_tags[-1])
except:
    pass
" 2>/dev/null
    fi
}

# Function to get latest version from git tags
get_git_version() {
    git tag -l "v*" | sort -V | tail -n 1
}

# Determine version tag
if [ -n "$VERSION" ]; then
    # Manual version specified
    TAG_VERSION="${DOCKER_USERNAME}/${IMAGE_NAME}:v${VERSION}"
    echo "Using manually specified version: v${VERSION}"
else
    # Auto-detect next version
    echo "Detecting latest version..."

    # Get versions from both sources
    DOCKERHUB_TAG=$(get_dockerhub_version)
    GIT_TAG=$(get_git_version)

    # Determine which version to use
    if [ -n "$DOCKERHUB_TAG" ]; then
        LATEST_TAG="$DOCKERHUB_TAG"
        echo "Found latest version on Docker Hub: $DOCKERHUB_TAG"

        # Warn if git tag differs
        if [ -n "$GIT_TAG" ] && [ "$GIT_TAG" != "$DOCKERHUB_TAG" ]; then
            echo "WARNING: Git tag ($GIT_TAG) differs from Docker Hub ($DOCKERHUB_TAG)"
            echo "Using Docker Hub version as source of truth"
        fi
    elif [ -n "$GIT_TAG" ]; then
        LATEST_TAG="$GIT_TAG"
        echo "Docker Hub query failed, using git tag: $GIT_TAG"
    else
        LATEST_TAG=""
        echo "No existing versions found"
    fi

    # Calculate next version
    if [ -z "$LATEST_TAG" ]; then
        # No existing tags, start with v3.0
        TAG_VERSION="${DOCKER_USERNAME}/${IMAGE_NAME}:v3.0"
        echo "Starting fresh with v3.0"
    else
        # Extract and increment version
        MAJOR=$(echo $LATEST_TAG | cut -d. -f1 | sed 's/v//')
        MINOR=$(echo $LATEST_TAG | cut -d. -f2)
        MINOR=$((MINOR + 1))
        TAG_VERSION="${DOCKER_USERNAME}/${IMAGE_NAME}:v${MAJOR}.${MINOR}"
        echo "Incrementing to v${MAJOR}.${MINOR}"
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
