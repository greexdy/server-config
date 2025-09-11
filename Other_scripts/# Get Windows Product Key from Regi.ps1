# Get Windows Product Key from Registry / BIOS
function Get-WindowsProductKey {
    # Registry path for DigitalProductId
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
    $digitalProductId = (Get-ItemProperty -Path $regPath).DigitalProductId

    function ConvertTo-Key([byte[]]$digitalProductId) {
        $key = ""
        $keyChars = "BCDFGHJKMPQRTVWXY2346789"
        $isWin8OrUp = ($digitalProductId[66] / 6) -band 1
        $digitalProductId[66] = ($digitalProductId[66] -band 0xF7) -bor (($isWin8OrUp -band 2) * 4)

        $last = 0
        for ($i = 24; $i -ge 0; $i--) {
            $current = 0
            for ($j = 14; $j -ge 0; $j--) {
                $current = $current * 256
                $current = $digitalProductId[$j + 52] + $current
                $digitalProductId[$j + 52] = [math]::Floor($current / 24)
                $current = $current % 24
            }
            $key = $keyChars[$current] + $key
            $last = $current
        }

        $key = $key.Substring(1, $last) + "N" + $key.Substring($last + 1)
        return ($key -replace ".{5}",'$&-').TrimEnd("-")
    }

    if ($digitalProductId) {
        return ConvertTo-Key $digitalProductId
    } else {
        return "Product Key not found in registry."
    }
}

Write-Output "Windows Product Key: $(Get-WindowsProductKey)"
