$graph:
  - baseCommand: s-expression
    class: CommandLineTool
    hints:
      DockerRequirement:
        dockerPull: eoepca/s-expression:dev0.0.2
    id: clt
    inputs:
      input_reference:
        inputBinding:
          position: 1
          prefix: --input_reference
        type: Directory
      s_expression:
        inputBinding:
          position: 2
          prefix: --s-expression
        type: string
      cbn:
        inputBinding:
          position: 3
          prefix: --cbn
        type: string
    outputs:
      results:
        outputBinding:
          glob: .
        type: Directory
    requirements:
      EnvVarRequirement:
        envDef:
          PATH: /srv/conda/envs/env_app_snuggs/bin:/srv/conda/envs/env_app_snuggs/bin:/srv/conda/bin:/srv/conda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
      ResourceRequirement: {}
    #stderr: std.err
    #stdout: std.out
  - class: Workflow
    doc: Applies s expressions to EO acquisitions
    id: s-expression
    inputs:
      input_reference:
        doc: Input product reference
        label: Input product reference
        type: Directory
      s_expression:
        doc: s expression
        label: s expression
        type: string
      cbn:
        doc: Common band name
        label: Common band name
        type: string
    label: s expressions
    outputs:
      - id: wf_outputs
        outputSource:
          - step_1/results
        type: Directory
    steps:
      step_1:
        in:
          input_reference: input_reference
          s_expression: s_expression
          cbn: cbn
        out:
          - results
        run: "#clt"
$namespaces:
  s: https://schema.org/
cwlVersion: v1.0
s:version: 0.0.2
s:softwareVersion: 0.0.2
s:citation: https://github.com/EOEPCA/app-s-expression#readme
s:codeRepository: https://github.com/EOEPCA/app-s-expression
s:dateCreated: "2022-05-03"
s:keywords: "s-expression, processing, EO, bands"
s:license: https://raw.githubusercontent.com/EOEPCA/eoepca/develop/LICENSE
s:releaseNotes: https://raw.githubusercontent.com/EOEPCA/app-s-expression/main/README.md
s:author:
  - class: s:Person
    s:name: Eoepca Developer
    s:email: developer@eoepca.org
    s:affiliation: EOEPCA
s:contributor:
  - class: s:Person
    s:name: Community Developer
    s:email: s:contributor@community.org
    s:affiliation: Community
schemas:
  - http://schema.org/version/9.0/schemaorg-current-http.rdf
