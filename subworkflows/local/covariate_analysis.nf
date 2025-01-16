process check_relation {
    publishDir params.outdir+'/results', mode: params.publish_dir_mode

    input:
    path covariates
    path phenotypes
    
    output:
    file "boxplot_*.png"

    script:
    """
    #!/usr/bin/env python3
    import pandas as pd
    import seaborn as sns
    import matplotlib.pyplot as plt

    covars = pd.read_csv('$covariates', sep='\t')
    pheno = pd.read_csv('$phenotypes', sep='\t')

    df = pd.merge(covars, pheno, on='SAMPLE')

    for col in covars.columns:
        if col != 'SAMPLE':
            for col2 in pheno.columns:
                if col2 != 'SAMPLE':
                    plt.figure(figsize=(20, 10))
                    sns.boxplot(x=col2, y=col, data=df, color="lightgreen")
                    sns.swarmplot(x=col2, y=col, data=df, color="darkgreen")
                    plt.savefig(f'boxplot_{col}_{col2}.png')
                    plt.close()
    
    """
}
workflow CONTRIBUTION_TEST {
    take:
    phenotypes
    covariates

    main:
    ch_phenotypes = Channel.fromPath(phenotypes)
    ch_covariates = Channel.fromPath(covariates)

    check_relation(ch_phenotypes, ch_covariates)
}