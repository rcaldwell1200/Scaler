$now = get-date -Format yyyyMMddHHmm
$os = Get-Ciminstance Win32_OperatingSystem
$cpustat = Get-WmiObject win32_processor | select LoadPercentage -ExpandProperty LoadPercentage
$pctFree = [math]::Round(($os.FreePhysicalMemory/$os.TotalVisibleMemorySize)*100,2)
$usage = 100-$pctFree
$free = Get-WmiObject win32_logicaldisk -Filter "DeviceID='C:'" | select -ExpandProperty FreeSpace
$size = Get-WmiObject win32_logicaldisk -Filter "DeviceID='C:'" | select -ExpandProperty Size
$dskstat = [math]::Round(($free/$size)*100,2)
Invoke-Sqlcmd -Database Scaling -ServerInstance "EP6SQL01\REPORTING" -Query "INSERT INTO hoststat VALUES ('$now','$env:COMPUTERNAME','1','$usage','$cpustat','$dskstat')"