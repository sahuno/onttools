#!/usr/bin/env python3
"""
Example script for allelic-specific methylation analysis
using Oxford Nanopore sequencing data
"""

import os
import subprocess
import pandas as pd
import numpy as np
import pysam
from pathlib import Path
import argparse
import logging
from typing import Dict, List, Tuple

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class MethylationAnalyzer:
    """Class to handle allelic-specific methylation analysis"""
    
    def __init__(self, output_dir: str):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
    def run_dorado(self, pod5_dir: str, model: str = "dna_r10.4.1_e8.2_400bps_sup@v4.3.0") -> str:
        """Run Dorado basecaller with methylation calling"""
        logger.info("Running Dorado basecaller...")
        output_bam = self.output_dir / "basecalls.bam"
        
        # Use the super accurate model with 5mC and 5hmC calling
        cmd = [
            "dorado", "basecaller",
            model,
            pod5_dir,
            "--modified-bases", "5mCG_5hmCG",
            "--emit-moves",
            "--device", "cuda:all"
        ]
        
        with open(output_bam, 'w') as f:
            subprocess.run(cmd, stdout=f, check=True)
        
        # Sort and index
        sorted_bam = self.output_dir / "basecalls.sorted.bam"
        pysam.sort("-o", str(sorted_bam), str(output_bam))
        pysam.index(str(sorted_bam))
        
        return str(sorted_bam)
    
    def extract_methylation(self, bam_file: str, reference: str) -> str:
        """Extract methylation information using modkit"""
        logger.info("Extracting methylation with modkit...")
        methyl_bed = self.output_dir / "methylation.bed"
        
        cmd = [
            "modkit", "extract",
            bam_file,
            str(methyl_bed),
            "--ref", reference,
            "--threads", "8",
            "--log-level", "info"
        ]
        
        subprocess.run(cmd, check=True)
        return str(methyl_bed)
    
    def call_variants(self, bam_file: str, reference: str) -> str:
        """Call variants using Sniffles"""
        logger.info("Calling variants with Sniffles...")
        vcf_file = self.output_dir / "variants.vcf"
        
        cmd = [
            "sniffles",
            "-i", bam_file,
            "-v", str(vcf_file),
            "--reference", reference,
            "--threads", "8"
        ]
        
        subprocess.run(cmd, check=True)
        return str(vcf_file)
    
    def phase_reads(self, bam_file: str, vcf_file: str, reference: str) -> Tuple[str, str]:
        """Phase reads using WhatsHap"""
        logger.info("Phasing reads with WhatsHap...")
        phased_vcf = self.output_dir / "phased.vcf"
        phased_bam = self.output_dir / "phased.bam"
        
        # Phase variants
        cmd_phase = [
            "whatshap", "phase",
            "-o", str(phased_vcf),
            "--reference", reference,
            vcf_file, bam_file
        ]
        subprocess.run(cmd_phase, check=True)
        
        # Tag reads with haplotype
        cmd_tag = [
            "whatshap", "haplotag",
            "-o", str(phased_bam),
            "--reference", reference,
            str(phased_vcf), bam_file
        ]
        subprocess.run(cmd_tag, check=True)
        
        # Index the phased BAM
        pysam.index(str(phased_bam))
        
        return str(phased_vcf), str(phased_bam)
    
    def analyze_allelic_methylation(self, phased_bam: str, methyl_bed: str) -> pd.DataFrame:
        """Analyze methylation by haplotype"""
        logger.info("Analyzing allelic methylation...")
        
        # Read methylation data
        methyl_df = pd.read_csv(
            methyl_bed, 
            sep='\t',
            names=['chrom', 'start', 'end', 'read_name', 'score', 'strand', 
                   'thick_start', 'thick_end', 'color', 'coverage', 'methylated']
        )
        
        # Extract haplotype information from phased BAM
        haplotype_dict = {}
        with pysam.AlignmentFile(phased_bam, "rb") as bamfile:
            for read in bamfile:
                if read.has_tag('HP'):
                    haplotype = read.get_tag('HP')
                    haplotype_dict[read.query_name] = haplotype
        
        # Add haplotype information to methylation data
        methyl_df['haplotype'] = methyl_df['read_name'].map(haplotype_dict)
        
        # Calculate methylation by haplotype
        results = []
        for region in methyl_df.groupby(['chrom', 'start', 'end']):
            chrom, start, end = region[0]
            data = region[1]
            
            for hap in [1, 2]:
                hap_data = data[data['haplotype'] == hap]
                if len(hap_data) > 0:
                    methyl_rate = hap_data['methylated'].sum() / hap_data['coverage'].sum()
                    results.append({
                        'chrom': chrom,
                        'start': start,
                        'end': end,
                        'haplotype': hap,
                        'methylation_rate': methyl_rate,
                        'n_reads': len(hap_data)
                    })
        
        results_df = pd.DataFrame(results)
        results_df.to_csv(self.output_dir / "allelic_methylation.csv", index=False)
        
        return results_df
    
    def generate_report(self, results_df: pd.DataFrame):
        """Generate MultiQC report"""
        logger.info("Generating MultiQC report...")
        
        # Create MultiQC config
        config = {
            'title': 'Allelic Methylation Analysis Report',
            'intro_text': 'Analysis of allele-specific methylation patterns in cancer samples'
        }
        
        config_file = self.output_dir / "multiqc_config.yaml"
        import yaml
        with open(config_file, 'w') as f:
            yaml.dump(config, f)
        
        # Run MultiQC
        cmd = [
            "multiqc",
            str(self.output_dir),
            "-o", str(self.output_dir),
            "-c", str(config_file)
        ]
        subprocess.run(cmd, check=True)


def main():
    parser = argparse.ArgumentParser(description='Allelic methylation analysis pipeline')
    parser.add_argument('--pod5-dir', required=True, help='Directory containing POD5 files')
    parser.add_argument('--reference', required=True, help='Reference genome FASTA')
    parser.add_argument('--output-dir', default='results', help='Output directory')
    parser.add_argument('--skip-basecalling', action='store_true', help='Skip basecalling step')
    parser.add_argument('--bam-file', help='Pre-existing BAM file (if skipping basecalling)')
    
    args = parser.parse_args()
    
    # Initialize analyzer
    analyzer = MethylationAnalyzer(args.output_dir)
    
    # Run pipeline
    if not args.skip_basecalling:
        bam_file = analyzer.run_dorado(args.pod5_dir)
    else:
        if not args.bam_file:
            raise ValueError("--bam-file required when --skip-basecalling is set")
        bam_file = args.bam_file
    
    # Extract methylation
    methyl_bed = analyzer.extract_methylation(bam_file, args.reference)
    
    # Call variants
    vcf_file = analyzer.call_variants(bam_file, args.reference)
    
    # Phase reads
    phased_vcf, phased_bam = analyzer.phase_reads(bam_file, vcf_file, args.reference)
    
    # Analyze allelic methylation
    results = analyzer.analyze_allelic_methylation(phased_bam, methyl_bed)
    
    # Generate report
    analyzer.generate_report(results)
    
    logger.info(f"Analysis complete! Results saved to {args.output_dir}")


if __name__ == "__main__":
    main()
