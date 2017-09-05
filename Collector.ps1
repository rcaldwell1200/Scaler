$now = get-date -Format yyyyMMddHHmm
$os = Get-Ciminstance Win32_OperatingSystem
$cpustat = Get-WmiObject win32_processor | select LoadPercentage -ExpandProperty LoadPercentage
$pctFree = [math]::Round(($os.FreePhysicalMemory/$os.TotalVisibleMemorySize)*100,2)
$usage = 100-$pctFree
$free = Get-WmiObject win32_logicaldisk -Filter "DeviceID='C:'" | select -ExpandProperty FreeSpace
$size = Get-WmiObject win32_logicaldisk -Filter "DeviceID='C:'" | select -ExpandProperty Size
$dskstat = [math]::Round(($free/$size)*100,2)
#network
$colInterfaces = Get-WmiObject -class Win32_PerfFormattedData_Tcpip_NetworkInterface |select BytesTotalPersec, CurrentBandwidth,PacketsPersec|where {$_.PacketsPersec -gt 0}

foreach ($interface in $colInterfaces) {
$bitsPerSec = $interface.BytesTotalPersec * 8
$totalBits = $interface.CurrentBandwidth

# Exclude Nulls (any WMI failures)
if ($totalBits -gt 0) {
$result = (( $bitsPerSec / $totalBits) * 100)
}
}
$netstat = $result*100
 

Invoke-Sqlcmd -Database Scaling -ServerInstance "EP6SQL01\REPORTING" -Query "INSERT INTO hoststat VALUES ('$now','$env:COMPUTERNAME','$netstat','$usage','$cpustat','$dskstat')"