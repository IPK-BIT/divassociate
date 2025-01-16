include { plot_overview } from '../../modules/local/manhattan_plots'
include { plot_chromosome_overview } from '../../modules/local/manhattan_plots.nf'

process splitChromosome{
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

workflow PREPARE_OUTPUTS {
    take:
    assoc

    main:
    plot_overview(assoc)

    splitChromosome(assoc)
    | flatten
    | plot_chromosome_overview
}