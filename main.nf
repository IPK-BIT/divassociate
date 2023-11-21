process computeKinship{
  container 'quay.io/biocontainers/gemma:0.98.3--hb4ccc14_0'
  publishDir "params.outdir", mode: 'copy'

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

workflow {
  computeKinship('tibia', params.genoFile, params.phenoFile, params.mapFile)
}