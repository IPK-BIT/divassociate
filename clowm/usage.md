# Usage Guide for the Workflow
This workflow is implemented to perform a genomewide association study using the GEMMA software. It uses a VCF file as input for the genotyping data and a csv file for the phenotyping data.

## Workflow Overview
The workflow is composed of several processes, each performing a specific task in the pipeline. These processes include:

- `prepareVcf`: Extract the genotypes for the samples.
- `transformVcfToPlink`: Transforms a VCF file to PLINK format.
- `preparePhenotypes`: Extracts phenotypic data from the CSV file.
- `combineFamWithPhenotypes`: Combines genotyping data with the phenotype data.
- `computeRelatednessMatrix`: Computes a relatedness matrix using GEMMA.
- `performAssocTest`: Performs an association test using GEMMA.
- `plotOverview`: Plots genomewide manhattan plot of the association test results.
- `splitChromosome`: Splits the association results by chromosome.
- `plotChromosomewide`: Plots the association results for each chromosome as a manhattan plot.

## Workflow Execution
To execute the workflow, you need to provide the following inputs:

- `samples`: The CSV file containing the germplasm IDs to use for the GWAS.
- `vcf`: The VCF file to be transformed to PLINK format.
- `observations`: The CSV file containing the sample IDs and the observation values for the variable. Ordered the same as in `samples`
- `outdir`: The directory where the results will be saved.
