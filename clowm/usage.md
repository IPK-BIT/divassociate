# Usage Guide for the Workflow
This workflow is implemented to perform a genomewide association study using the GEMMA software. It uses a VCF file as input for the genotyping data and a TSV file for the phenotyping data as well as the sample selection.

## Workflow Overview
The workflow is composed of several processes, each performing a specific task in the pipeline. These processes include:
Each process is named in a self-descriptive manner and processes are grouped into subworkflows to faciliate understanding the role of each process.

## Workflow Execution
To execute the workflow, you need to provide the following inputs:

- `vcf`: The VCF file to be transformed to PLINK format.
- `samples`: The TSV file containing the germplasm IDs to use for the GWAS.
- `phenotypes`: The TSV file containing the sample IDs and the observation values for the variable. Ordered the same as in `samples`
- `covariates`: Optionally the TSV file containing the sample IDs and the covariates. Ordered the same as in `samples`
- `outdir`: The directory where the results will be saved.