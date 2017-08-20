## Set defaults
$globalAdd = $false
$globalDel = $false
$now = get-date -Format yyyyMMddHHmm
$reportTime = $now-5
$exceedNet = $false
$exceedDisk = $false
$exceedMem = $false
$exceedCpu = $false
$metricDiskUsg = '1'
## Metric Definitions
## Static items such as hard numbers
$metricNetMax = '70'
$metricNetMin = '40'
$metricCpuMax = '90'
$metricCpuMin = '20'
$metricMemMax = '90'
$metricMemMin = '40'
$metricMemCap = '100'
$metricCpuCap = '100'
$metricNetCap = '100'
## Metric Data Gathering
    ## Insert Collection script to collect information from machines here
## Data collected from SQL and then calculated
$metricSrvCnt = Invoke-Sqlcmd -Database Scaling -ServerInstance "EP6SQL01\REPORTING" -Query "select count(status) from hosts where status = 'Active';" | select -ExpandProperty "Column1"
$metricNetUsg = Invoke-Sqlcmd -Database Scaling -ServerInstance "EP6SQL01\REPORTING" -Query "select avg(net) from hoststat where time < '$reporttime';" | select -ExpandProperty "Column1"
$metricCpuUsg = Invoke-Sqlcmd -Database Scaling -ServerInstance "EP6SQL01\REPORTING" -Query "select avg(cpu) from hoststat where time < '$reporttime';" | select -ExpandProperty "Column1"
$metricMemUsg = Invoke-Sqlcmd -Database Scaling -ServerInstance "EP6SQL01\REPORTING" -Query "select avg(mem) from hoststat where time < '$reporttime';" | select -ExpandProperty "Column1"
[int]$namingSrvCnt = Invoke-Sqlcmd -Database Scaling -ServerInstance "EP6SQL01\REPORTING" -Query "select max(sequence) from hosts" | select -ExpandProperty "Column1"
$namingSrvCnt++
$metricOldAge = Invoke-Sqlcmd -Database Scaling -ServerInstance "EP6SQL01\REPORTING" -Query "select min(hostname) from hosts where status like 'Active'" | select -ExpandProperty "Column1"
## Determine Add/Remove
if ( $metricNetUsg -gt $metricNetMax ) {
    Set-Variable -Name globalAdd -Scope Global -Value $true
    Set-Variable -Name exceedNet -Scope Global -Value $true
    }
if ( $metricCpuUsg -gt $metricCpuMax ) {
    Set-Variable -Name globalAdd -Scope Global -Value $true
    Set-Variable -Name exceedCpu -Scope Global -Value $true
    }
if ( $metricMemUsg -gt $metricMemMax ) {
    Set-Variable -Name globalAdd -Scope Global -Value $true
    Set-Variable -Name exceedMem -Scope Global -Value $true
    }
if ( $metricNetUsg -lt $metricNetMin AND $metricCpuUsg -lt $metricCpuMin AND $metricMemUsg -lt $metricMemMin ) {
    Set-Variable -Name globalDel -Scope Global -Value $true
    }
Invoke-Sqlcmd -Database Scaling -ServerInstance "EP6SQL01\REPORTING" -Query "INSERT INTO stats VALUES ('$now','$metricNetUsg','$metricDiskUsg','$metricMemUsg','$metricCpuUsg','$exceedNet','$exceedDisk','$exceedMem','$exceedCpu');"
## Action Determination
## Take the known and calculated values to determine action to take
if ( $globalAdd ) {
    $vmname = "EP6Web"+$namingsrvcnt
    New-VM -Name $vmname -Template (Server 2012 R2 BASE Sysprepped) -Confirm
    $vmip = Get-VM -Name $vmname | select @{N="IP Address";E={@($_.guest.IPAddress[0])}} | select -ExpandProperty "IP Address"
    Invoke-Sqlcmd -Database Scaling -ServerInstance "EP6SQL01\REPORTING" -Query "INSERT INTO hosts VALUES ('$vmname','$vmip','active','$now');"
    Invoke-Sqlcmd -Database Scaling -ServerInstance "EP6SQL01\REPORTING" -Query "INSERT INTO record VALUES ('Created','$vmname','$vmip','$now','','');"
    }
if ( $globalDel ) {
    Stop-VM -Kill -Server EP6VCS01 -VM $metricOldAge
    Remove-VM -DeletePermanently -Server EP6VCS01 -VM $metricOldAge
    $metricOldIP = Invoke-Sqlcmd -Database Scaling -ServerInstance "EP6SQL01\REPORTING" -Query "SELECT hostip FROM hosts WHERE hostname = '$metricOldAge';"
    Invoke-Sqlcmd -Database Scaling -ServerInstance "EP6SQL01\REPORTING" -Query "UPDATE hosts SET status = 'inactive' WHERE hostname = '$metricOldAge';"
    Invoke-Sqlcmd -Database Scaling -ServerInstance "EP6SQL01\REPORTING" -Query "INSERT INTO record VALUES ('Deleted','$metricOldAge','$metricOldIP','$now','','');"
    }