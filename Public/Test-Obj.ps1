function Test-Obj {
    param (
    )

    $filepath="./Samples/SampleOnboard.yaml"
    $yaml = Get-Content -Raw $filePath
    $obj = ConvertFrom-Yaml $yaml

    return $obj

}
