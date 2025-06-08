#!/bin/bash
# Test script to verify all tools are installed correctly

echo "=== Testing Nanopore Methylation Docker Installation ==="
echo

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to test command
test_command() {
    local cmd=$1
    local name=$2
    
    if command -v $cmd &> /dev/null; then
        echo -e "${GREEN}✓${NC} $name is installed"
        $cmd --version 2>&1 | head -n 1 || $cmd -version 2>&1 | head -n 1 || echo "  Version info not available"
    else
        echo -e "${RED}✗${NC} $name is NOT installed"
        return 1
    fi
}

# Function to test Python package
test_python_package() {
    local package=$1
    
    if python -c "import $package" 2>/dev/null; then
        version=$(python -c "import $package; print(f'{$package.__version__}' if hasattr($package, '__version__') else 'installed')" 2>/dev/null || echo "installed")
        echo -e "${GREEN}✓${NC} Python package '$package' is installed (version: $version)"
    else
        echo -e "${RED}✗${NC} Python package '$package' is NOT installed"
        return 1
    fi
}

echo "=== Testing System Information ==="
echo "Python version: $(python --version)"
echo "CUDA available: $(nvidia-smi &>/dev/null && echo 'Yes' || echo 'No')"
echo

echo "=== Testing Nanopore Tools ==="
test_command "dorado" "Dorado"
test_command "modkit" "Modkit"
python -c "import pod5" 2>/dev/null && echo -e "${GREEN}✓${NC} Pod5 Python package is installed" || echo -e "${RED}✗${NC} Pod5 Python package is NOT installed"
echo

echo "=== Testing Alignment & Variant Tools ==="
test_command "samtools" "Samtools"
test_command "bcftools" "BCFtools"
test_command "tabix" "Tabix"
test_command "bgzip" "BGzip"
test_command "bedtools" "Bedtools"
test_command "sniffles" "Sniffles"
echo

echo "=== Testing Phasing Tools ==="
test_command "longphase" "Longphase"
test_command "whatshap" "WhatsHap"
echo

echo "=== Testing Analysis & Visualization Tools ==="
test_command "mosdepth" "Mosdepth"
test_command "multiqc" "MultiQC"
test_command "methylartist" "Methylartist"
test_command "deeptools" "DeepTools"
test_command "igv-reports" "IGV-reports"
echo

echo "=== Testing UCSC Utilities ==="
test_command "bedGraphToBigWig" "bedGraphToBigWig"
test_command "bigWigToBedGraph" "bigWigToBedGraph"
test_command "fetchChromSizes" "fetchChromSizes"
echo

echo "=== Testing Python Packages ==="
for package in pandas numpy matplotlib seaborn pysam cyvcf2 yaml packaging scipy sklearn plotly Bio; do
    test_python_package $package
done
echo

echo "=== Testing GPU Support ==="
if nvidia-smi &>/dev/null; then
    echo -e "${GREEN}✓${NC} NVIDIA GPU detected"
    nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader
    
    # Test CUDA
    python -c "import torch; print(f'PyTorch CUDA available: {torch.cuda.is_available()}')" 2>/dev/null || echo "PyTorch not installed (optional)"
else
    echo -e "${RED}✗${NC} No NVIDIA GPU detected (CPU mode only)"
fi
echo

echo "=== Installation Test Complete ==="
