$graph:

- class: Workflow
  doc: Applies s expressions to EO acquisitions
  id: snuggs
  requirements:
  - class: ScatterFeatureRequirement
  inputs:
    input_reference:
      doc: Input product reference
      label: Input product reference
      type: string[]
    s_expression:
      doc: s expression
      label: s expression
      type: string[]
  label: s expressions
  outputs:
  - id: wf_outputs
    outputSource:
    - step_1/results
    type:
      Directory[]

  steps:
    step_1:
      in:
        input_reference: input_reference
        s_expression: s_expression
      out:
      - results
      run: '#clt'
      scatter: [input_reference, s_expression]
      scatterMethod: flat_crossproduct


- baseCommand: s-expression
  class: CommandLineTool

  id: clt

  arguments:
  - --input_reference
  - valueFrom: $( inputs.input_reference )
  - --s-expression
  - valueFrom: ${ return inputs.s_expression.split(":")[1]; }
  - --cbn
  - valueFrom: ${ return inputs.s_expression.split(":")[0]; }

  inputs:
    input_reference:
      type: string
    s_expression:
      type: string

  outputs:
    results:
      outputBinding:
        glob: .
      type: Directory
  requirements:
    EnvVarRequirement:
      envDef:
        PATH: /srv/conda/envs/env_app_snuggs/bin:/srv/conda/bin:/srv/conda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    ResourceRequirement: {}
    InlineJavascriptRequirement: {}
    DockerRequirement:
      dockerPull: eoepca/snuggs:0.3.0
  #stderr: std.err
  #stdout: std.out

cwlVersion: v1.0

$namespaces:
  s: https://schema.org/
s:softwareVersion: 0.3.0
schemas:
- http://schema.org/version/9.0/schemaorg-current-http.rdf