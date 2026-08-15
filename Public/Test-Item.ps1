function Test-Item {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        #[Parameter(Mandatory=$false)]
        #[object]$obj,
        #[Parameter(Mandatory=$false)]
        [object]$cfg
    )


    #$cfg = $obj.items[0].items[0]


    $item = [ItemFactory]::Create($cfg)

    return $item
}
