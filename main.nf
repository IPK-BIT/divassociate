process transformVcfToPlink{
  container 'quay.io/biocontainers/plink:1.90b6.21--hec16e2b_4'
  
  input:
    path(vcfFile)
  output:
    path("${vcfFile.baseName}.bed"), emit: bedFile
    path("${vcfFile.baseName}.bim"), emit: bimFile
    path("${vcfFile.baseName}_modified.fam"), emit: famFile

  script:
  """
  plink --allow-extra-chr --keep-allele-order --vcf ${vcfFile} --make-bed --out ${vcfFile.baseName} 
  cut -d' ' -f1,2,3,4,5 ${vcfFile.baseName}.fam > ${vcfFile.baseName}_modified.fam
  """
}

process extractSampleNames{
  container 'quay.io/biocontainers/bcftools:1.18--h8b25389_0'

  input:
    path(vcfFile)
  output:
    path("list_of_samples.txt")
  
  script:
  """
  bcftools query -l $vcfFile > list_of_samples.txt
  """
}

process extractPhenotypes{
  container 'quay.io/biocontainers/pandas:1.5.2'

  input:
    path(miappeFile)
    val(variable)
    path(sampleFile)
  output:
    path("${variable}.tsv")
  
  script:
  """
  #!/usr/bin/env python3
  import pandas as pd
  studyFile = pd.read_csv('$miappeFile'+'/s_study.txt', sep='\t')
  assayFile = pd.read_csv('$miappeFile'+'/a_phenotyping.txt', sep='\t')
  dataFile = pd.read_csv('$miappeFile'+'/df.txt', sep='\t')
  samples = pd.read_csv('$sampleFile', header=None)
  samples['Source Name'] = samples[0].replace({'_': ' ', '-BRI': ''}, regex=True)

  df = pd.merge(samples,pd.merge(pd.merge(studyFile, assayFile, on='Sample Name'), dataFile, on='Assay Name').sort_values(by=['Source Name']), on='Source Name', how='outer')
  df['$variable'].to_csv('${variable}.tsv', sep='\t', header=False, index=False)
  """
}

process combineFamWithPhenotypes{
  container 'quay.io/biocontainers/plink:1.90b6.21--hec16e2b_4'

  input:
    path(phenoFile)
    path(famFile)
  output:
    path("${famFile.baseName.replaceAll('_modified', '')}.fam")

  script:
  """
  paste -d ' ' $famFile $phenoFile > tmp.fam
  mv tmp.fam ${famFile.baseName.replaceAll('_modified', '')}.fam
  """
}

process computeRelatednessMatrix {
  container 'quay.io/biocontainers/gemma:0.98.3--hb4ccc14_0'
  publishDir params.outdir+'/results', mode: 'copy'

  input:
    path(bedFile)
    path(bimFile)
    path(famFile)
  output:
    path("${famFile.baseName}.cXX.txt")
  script:
  """
  gemma -bfile $bedFile.baseName -gk 1 -outdir . -o ${famFile.baseName}
  """
}

process performAssocTest {
  container 'quay.io/biocontainers/gemma:0.98.3--hb4ccc14_0'
  publishDir params.outdir+'/results', mode: 'copy'

  input:
    path(bedFile)
    path(bimFile)
    path(famFile)
    // path(covarFile)
    path(relatMatrix)
  output:
    path("${famFile.baseName}.assoc.txt")
  script:
  """
  gemma -bfile $bedFile.baseName -k $relatMatrix -lmm 2 -notsnp -outdir . -o ${famFile.baseName}
  """
}

process plotOverview{
  container "amaksimov/python_data_science"
  publishDir params.outdir+'/plots', mode: 'copy'

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
  container "amaksimov/python_data_science"
  // container 'quay.io/biocontainers/pandas:1.5.2'

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
  container "amaksimov/python_data_science"
  // container 'quay.io/biocontainers/matplotlib:3.5.1'
  publishDir params.outdir+'/plots', mode: 'copy'

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
  transformVcfToPlink(params.vcf) 
  extractSampleNames(params.vcf)

  //Prepare the phenotyping data
  extractPhenotypes(params.miappe, params.variable, extractSampleNames.out) 
  combineFamWithPhenotypes(extractPhenotypes.out, transformVcfToPlink.out.famFile)

  //Start the LMM-based association analysis
  computeRelatednessMatrix(transformVcfToPlink.out.bedFile, transformVcfToPlink.out.bimFile, combineFamWithPhenotypes.out)
  performAssocTest(transformVcfToPlink.out.bedFile, transformVcfToPlink.out.bimFile, combineFamWithPhenotypes.out, computeRelatednessMatrix.out)
  
  //Start plotting the results
  plotOverview(performAssocTest.out)
  splitChromosome(performAssocTest.out)
    | flatten
    | plotChromosomewide
}