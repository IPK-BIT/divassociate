process plot_overview {
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

    ax.set_xlabel('Chromosome')
    ax.set_ylabel('-log10 p-value')
    plt.axhline(y=3.2, color='r', linestyle='--')
    plt.savefig('.'.join('${assocFile}'.split('.')[0:-1])+'_gwas_plot.png')
    """
}

process plot_chromosome_overview {
    publishDir params.outdir+'/plots', mode: 'copy'

    input:
    each path(assocFile)

    output:
    path '*_scatter.png'

    script:
    """
    #!/usr/bin/env python3
    import pandas as pd
    import numpy as np
    import matplotlib.pyplot as plt

    df=pd.read_csv('$assocFile', sep='\t')
    df['minuslog10pvalue']=-np.log10(df.p_lrt)
    df['ps'] = df['ps']/1e6
    ax=df.plot.scatter('ps', 'minuslog10pvalue', color="darkgreen")
    ax.set_xlabel('Basepair position [Mb]')
    ax.set_ylabel('-log10 p-value')
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    fig = ax.get_figure()
    fig.line = plt.axhline(y=3.2, color='r', linestyle='--')
    fig.savefig('.'.join('${assocFile}'.split('.')[0:-1])+'_scatter.png')
    """
}