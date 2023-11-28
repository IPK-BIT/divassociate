process transformVcfToPlink{
  container 'quay.io/biocontainers/plink:1.90b6.21--hec16e2b_4'
  
  input:
    path(vcfFile)
  output:
    path("${vcfFile.baseName}.bed"), emit: bedFile
    path("${vcfFile.baseName}.bim"), emit: bimFile
    path("${vcfFile.baseName}.fam"), emit: famFile

  script:
  """
  plink --allow-extra-chr --keep-allele-order --vcf ${vcfFile} --make-bed --out ${vcfFile.baseName} 
  """
}

process extractPhenotypes{
  // container "amaksimov/python_data_science"
  container 'quay.io/biocontainers/pandas:1.5.2'

  input:
    path(miappeFile)
  output:
    stdout
    //path('phenotypes.tsv')
  
  //TODO: Merge with fam file here?
  //FIXME: BRI in the genotype names?
  script:
  """
  #!/usr/bin/env python3
  import pandas as pd
  studyFile = pd.read_csv('$miappeFile'+'/s_study.txt', sep='\t')
  assayFile = pd.read_csv('$miappeFile'+'/a_phenotyping.txt', sep='\t')
  dataFile = pd.read_csv('$miappeFile'+'/df.txt', sep='\t')
  
  df = pd.merge(pd.merge(studyFile, assayFile, on='Sample Name'), dataFile, on='Assay Name')
  print(df)
  """
}

process combineFamWithPhenotypes{
  container ""

  input:
    path(famFile)
    path(phenoFile)
  output:
    path(famFile)
  
  script:
  """

  """
}

process computeKinship{
  container 'quay.io/biocontainers/gemma:0.98.3--hb4ccc14_0'

  input:
    val(name)
    path(genoFile)
    path(phenoFile)
    path(annoFile)
  output:
    path("${name}.cXX.txt")

  script:
  """
  gemma -p $phenoFile -g $genoFile -a $annoFile -gk 1 -outdir . -o ${name}
  """
}

process lmmAnalysis{
  container 'quay.io/biocontainers/gemma:0.98.3--hb4ccc14_0'
  publishDir params.outdir, mode: 'copy'

  input:
    path(kinshipFile)
    path(genoFile)
    path(phenoFile)
    path(annoFile)
    path(covarFile)
    val(name)
  output:
    path("${name}_lmm.assoc.txt")

  script:
  """
  gemma -p $phenoFile -c $covarFile -a $annoFile -g $genoFile -notsnp -k $kinshipFile -lmm 2 -outdir . -o ${name}_lmm
  """
}

process plotOverview{
  // TODO: Replace with self-maintained docker image
  // container "amaksimov/python_data_science"
  container 'quay.io/biocontainers/matplotlib:3.5.1'
  publishDir params.outdir, mode: 'copy'

  input:
    path(assocFile)
  output:
    path("*.png")
  
  script:
  """
  #!/usr/bin/env python3
  import pandas as pd
  import numpy as np
  import matplotlib.pyplot as plt

  gwscan = pd.read_csv('$assocFile', sep='\t')
  
  gwscan['minuslog10pvalue'] = -np.log10(gwscan.p_lrt)

  gwscan['ind'] = range(len(gwscan))
  gwscan_grouped = gwscan.groupby(('chr'))

  fig = plt.figure(figsize=(14,8))
  ax = fig.add_subplot(111)
  colors=['lightgreen', 'darkgreen']
  x_labels = []
  x_labels_pos = []
  for num, (name, group) in enumerate(gwscan_grouped):
      group.plot(kind='scatter', x='ind', y='minuslog10pvalue', color=colors[num % len(colors)], ax=ax)
      x_labels.append(name)
      x_labels_pos.append((group['ind'].iloc[-1]-(group['ind'].iloc[-1]-group['ind'].iloc[0])/2))
  ax.set_xticks(x_labels_pos)
  ax.set_xticklabels(x_labels)

  ax.set_xlim([0,len(gwscan)])
  #ax.set_ylim([0,3.5])

  ax.set_xlabel('Chromosome')
  ax.set_ylabel('-log10 p-value')
  plt.savefig('.'.join('${assocFile}'.split('.')[0:-1])+'_gwas_plot.png')
  """
}

process splitChromosome{
  // TODO: Replace with self-maintained docker image
  // container "amaksimov/python_data_science"
  container 'quay.io/biocontainers/pandas:1.5.2'

  input:
    path(assocFile)
  output:
    path("*.txt")

  script:
  """
  #!/usr/bin/env python3
  import pandas as pd

  df = pd.read_csv('$assocFile', sep='\t')
  groups = df.groupby(('chr'))
  for num, (name, group) in enumerate(groups):
      group.to_csv('.'.join('${assocFile}'.split('.')[0:-1])+'_chr'+str(name)+'.txt', sep='\t')
  """

}

process plotChromosomewide {
    // container "amaksimov/python_data_science"
    container 'quay.io/biocontainers/pandas:1.5.2'
    publishDir params.outdir, mode: 'copy'

    input:
        each path(assocFile)
    output:
        path '*_scatter.png'
    
    """
    #!/usr/bin/env python3
    import pandas as pd
    import numpy as np

    df=pd.read_csv('$assocFile', sep='\t')
    df['minuslog10pvalue']=-np.log10(df.p_lrt)
    df['ps'] = df['ps']/1e6
    ax=df.plot.scatter('ps', 'minuslog10pvalue', color="darkgreen")
    ax.set_xlabel('Basepair position [Mb]')
    ax.set_ylabel('-log10 p-value')
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    fig = ax.get_figure()
    fig.savefig('.'.join('${assocFile}'.split('.')[0:-1])+'_scatter.png')
    """
}

workflow {
  //Prepare the genotyping data
  // transformVcfToPlink(params.vcf) 

  //Prepare the phenotyping data
  // extractPhenotypes(params.miappe) | view { it }
    // | combineFamWithPhenotypes

  //Start the LMM-based association analysis
  computeKinship('tibia', params.genoFile, params.phenoFile, params.mapFile)
  lmmAnalysis(computeKinship.out, params.genoFile, params.phenoFile, params.mapFile, params.covarFile, 'tibia')

  //Start plotting the results
  plotOverview(lmmAnalysis.out)
  splitChromosome(lmmAnalysis.out)
    | flatten
    | plotChromosomewide
}