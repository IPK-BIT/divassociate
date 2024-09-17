process prepareVcf{
  label 'tiny'
  container 'quay.io/biocontainers/bcftools:1.18--h8b25389_0'
  
  input:
    path(vcfFile)
    path(sampleFile)
  output:
    path("${vcfFile.baseName}.vcf.gz")

  script:
  """
  bcftools view -Oz -o ${vcfFile.baseName}.vcf.gz -S $sampleFile $vcfFile
  """
}

process transformVcfToPlink{
  label 'medium'
  container 'quay.io/biocontainers/plink:1.90b6.21--hec16e2b_4'
  
  input:
    path(vcfFile)
  output:
    path("${vcfFile.baseName}.bed"), emit: bedFile
    path("${vcfFile.baseName}.bim"), emit: bimFile
    path("${vcfFile.baseName}_modified.fam"), emit: famFile

  script:
  """
  plink --allow-extra-chr --keep-allele-order --vcf ${vcfFile} --make-bed --out ${vcfFile.baseName} --double-id
  cut -d' ' -f1,2,3,4,5 ${vcfFile.baseName}.fam > ${vcfFile.baseName}_modified.fam
  """
}

process preparePhenotypes{
  label 'tiny'
  input:
    path(phenotypeFile)
  output:
    path("phenotypes.csv")

  script:
  """
  cut -d',' -f2 $phenotypeFile > phenotypes.csv
  """
}

process combineFamWithPhenotypes{
  label 'medium'
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
  label 'medium'
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
  label 'large'
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
  label 'tiny'
  container 'quay.io/biocontainers/mulled-v2-d0aaa59a9c102cbb5fb1b38822949827c5119e45:a53fc5f5fda400a196436eac5c44ff3e2d42b0dc-0'
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
  label 'tiny'
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
  label 'tiny'
  container 'quay.io/biocontainers/mulled-v2-d0aaa59a9c102cbb5fb1b38822949827c5119e45:a53fc5f5fda400a196436eac5c44ff3e2d42b0dc-0'
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
  // ## Prepare the genotyping data ##
  prepareVcf(params.vcf, params.samples)
  transformVcfToPlink(prepareVcf.out) 

  // ## Prepare the phenotyping data ##
  preparePhenotypes(params.observations)
  combineFamWithPhenotypes(preparePhenotypes.out, transformVcfToPlink.out.famFile)

  // ## Start the LMM-based association analysis ##
  computeRelatednessMatrix(transformVcfToPlink.out.bedFile, transformVcfToPlink.out.bimFile, combineFamWithPhenotypes.out)
  performAssocTest(transformVcfToPlink.out.bedFile, transformVcfToPlink.out.bimFile, combineFamWithPhenotypes.out, computeRelatednessMatrix.out)
  
  // // ## Start plotting the results ##
  plotOverview(performAssocTest.out)
  splitChromosome(performAssocTest.out)
    | flatten
    | plotChromosomewide
}
