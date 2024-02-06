cwlVersion: v1.0
$namespaces:
  s: https://schema.org/
s:softwareVersion: 0.1.2
schemas:
  - http://schema.org/version/9.0/schemaorg-current-http.rdf
$graph:
  # Workflow entrypoint
  - class: Workflow
    id: convert-stac
    label: convert stac app
    doc: Convert Stac
    requirements:
      ResourceRequirement:
        coresMax: 1
        ramMax: 1024
    inputs:
      fn:
        label: the operation to perform
        doc: the operation to perform
        type: string
      stac:
        label: the image to convert as a STAC item
        doc: the image to convert as a STAC item
        type: Directory
      size:
        label: the percentage for a resize operation
        doc: the percentage for a resize operation
        type: string
    outputs:
      - id: converted_image
        type: Directory
        outputSource:
          - convert/results
    steps:
      convert:
        run: "#convert"
        in:
          fn: fn
          stac: stac
          size: size
        out:
          - results
  # convert.sh - takes input args `--stac`
  - class: CommandLineTool
    id: convert
    requirements:
      ResourceRequirement:
        coresMax: 1
        ramMax: 512
    hints:
      DockerRequirement:
        dockerPull: eoepca/convert:latest
    baseCommand: convert.sh
    inputs:
      fn:
        type: string
        inputBinding:
          position: 1
      stac:
        type: Directory
        inputBinding:
          position: 2
          prefix: --stac
      size:
        type: string
        inputBinding:
          position: 3
    outputs:
      results:
        type: Directory
        outputBinding:
          glob: .
