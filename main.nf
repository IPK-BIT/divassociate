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
  container "amaksimov/python_data_science"
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

    gwscan = pd.read_csv('$assoc', sep='\t')
    
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
    plt.savefig('.'.join('${assoc}'.split('.')[0:-1])+'_gwas_plot.png')
  """
}

workflow {
  computeKinship('tibia', params.genoFile, params.phenoFile, params.mapFile)
  lmmAnalysis(computeKinship.out, params.genoFile, params.phenoFile, params.mapFile, params.covarFile, 'tibia')
  plotOverview(lmmAnalysis.out)
}