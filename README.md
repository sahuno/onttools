# Nanopore Methylation Analysis Docker Environment

This Docker image provides a comprehensive environment for analyzing allelic-specific methylation from Oxford Nanopore sequencing data in human cancer samples.

## Features

- **GPU Support**: CUDA 12.3.1 enabled for GPU acceleration
- **Python 3.12**: Latest Python version with all required packages
- **Complete Toolset**: All necessary bioinformatics tools pre-installed
- **HPC Ready**: Optimized for SLURM environments with Singularity support

## Included Software

### Nanopore Tools
- **Dorado** (v0.5.3): High-performance basecaller
- **Pod5**: File format tools
- **Modkit**: DNA methylation analysis from modified basecalls

### Variant Calling & Phasing
- **Sniffles**: Structural variant caller
- **Longphase**: Long-read phasing tool
- **WhatsHap**: Read-based phasing

### General Bioinformatics Tools
- **Samtools** (v1.19): SAM/BAM manipulation
- **BCFtools** (v1.19): VCF/BCF manipulation
- **Bedtools** (v2.31.1): Genome arithmetic
- **Mosdepth** (v0.3.8): Fast coverage calculation

### Visualization & QC
- **Methylartist**: Methylation visualization
- **MultiQC**: Aggregate results from bioinformatics analyses
- **DeepTools**: Tools for exploring deep sequencing data
- **IGV-reports**: Generate HTML reports for IGV
- **UCSC Utilities**: Genome browser tools

### Python Packages
All requested Python packages are installed, including:
- pandas, numpy, matplotlib, seaborn
- pysam, cyvcf2
- pyyaml, packaging
- And more...

## Building the Image

### In GitHub Codespaces

1. Place all files in your codespace:
   - `Dockerfile`
   - `requirements.txt`
   - `build_docker.sh`
   - `test_installation.sh`
   - `example_methylation_analysis.py`
   - `.dockerignore`

2. Make the build script executable:
   ```bash
   chmod +x build_docker.sh
   ```

3. Build the image:
   ```bash
   ./build_docker.sh
   ```

### Manual Build

```bash
docker build -t sahuno/nanopore-methylation:latest .
```

### Automated Build with GitHub Actions

The repository includes a GitHub Actions workflow (`.github/workflows/docker-build.yml`) that automatically builds and pushes the Docker image when changes are made to the Dockerfile or requirements.txt. To use this:

1. Add your Docker Hub password as a GitHub secret named `DOCKER_PASSWORD`
2. Push changes to the main branch
3. The image will be automatically built and pushed to Docker Hub

## Usage

### Testing the Installation

After building or pulling the image, test that all tools are properly installed:

```bash
# Run the test script
docker run --rm sahuno/nanopore-methylation:latest test_installation

# Or interactively
docker run -it --rm sahuno/nanopore-methylation:latest bash
# Then inside the container:
test_installation
```

### Local Docker

```bash
# Run with GPU support
docker run --gpus all -it -v $(pwd):/data sahuno/nanopore-methylation:latest

# Run without GPU (CPU only)
docker run -it -v $(pwd):/data sahuno/nanopore-methylation:latest
```

### SLURM HPC with Singularity

1. Pull the image:
   ```bash
   singularity pull docker://sahuno/nanopore-methylation:latest
   ```

2. Submit SLURM job:
   ```bash
   #!/bin/bash
   #SBATCH --job-name=methylation-analysis
   #SBATCH --partition=gpu
   #SBATCH --gres=gpu:1
   #SBATCH --cpus-per-task=16
   #SBATCH --mem=64G
   #SBATCH --time=24:00:00

   module load singularity

   singularity exec --nv \
     --bind /path/to/data:/data \
     nanopore-methylation_latest.sif \
     python /data/your_analysis_script.py
   ```

## Example Workflow

```bash
# Inside the container

# 1. Basecall with Dorado
dorado basecaller dna_r10.4.1_e8.2_400bps_hac@v4.3.0 pod5_dir/ > calls.bam

# 2. Extract methylation with modkit
modkit extract calls.bam methylation.bed

# 3. Call variants with Sniffles
sniffles -i calls.bam -v variants.vcf

# 4. Phase reads with WhatsHap
whatshap phase -o phased.vcf --reference ref.fa variants.vcf calls.bam

# 5. Analyze allele-specific methylation
# Your custom analysis scripts here
```

## Data Organization

The container expects:
- Input data mounted to `/data`
- Results written to `/results`

```bash
docker run --gpus all -it \
  -v /path/to/input:/data \
  -v /path/to/output:/results \
  sahuno/nanopore-methylation:latest
```

## Troubleshooting

### GPU not detected
- Ensure NVIDIA Docker runtime is installed
- Check CUDA compatibility with `nvidia-smi`
- For Singularity, use `--nv` flag

### Out of memory
- Increase Docker memory limits
- For SLURM, request more memory with `--mem`

### Permission issues
- Run with appropriate user permissions
- Use `--user $(id -u):$(id -g)` flag if needed

## Updates

To update the software versions, modify the Dockerfile and rebuild:
- Check latest releases on respective GitHub repositories
- Update version numbers in Dockerfile
- Rebuild and push new image

## Support

For issues specific to:
- Individual tools: Check their respective documentation
- Docker setup: Open an issue with full error logs
- SLURM/HPC: Consult your system administrator:
