function Add-ToItemCollection {
    param(
        $Delimiter = ';',
        $Reference, # e.g. ENV:Path
        $Item, # e.g. 'C:\Project',
        [switch]$Append
    )

    $Existing = ( Get-Item -Path $Reference | Select -ExpandProperty Value ) -split $Delimiter | Where {$_ -ne $Item}
    if($Append)
    {
        $ToAdd = ( @($Existing) + $Item | Select -Unique ) -join $Delimiter
    }
    else
    {
        $ToAdd = ( @($Item) + @($Existing) | Select -Unique ) -join $Delimiter
    }
    Set-Item -Path $Reference -Value $ToAdd
}