$CpuLogFile = 'C:\' + (Get-Date -Format "yyyy-MM-dd") + '.json'

'CpuLogFile' >> $CpuLogFile
$computer 	= 'LocalHost'
$namespace 	= 'root\CIMV2'

$DateTime = (Get-Date -Format 'dd.MM.yyyy HH:mm:ss')
$objLogInfo = New-Object System.Object
$objLogInfo | Add-Member -MemberType NoteProperty -Name DateTime -Value $DateTime

$CpuLoadAverage = (Get-WmiObject win32_processor | Measure-Object -property LoadPercentage -Average | Select Average ).Average

$ProcessorStats = Get-WmiObject win32_processor
$ComputerCpu = $ProcessorStats.LoadPercentage
$ComputerCpu = $ComputerCpu
# Lets create a re-usable WMI method for memory stats
$OperatingSystem = Get-WmiObject win32_OperatingSystem
# Lets grab the free memory
$FreeMemory = $OperatingSystem.FreePhysicalMemory
# Lets grab the total memory
$TotalMemory = $OperatingSystem.TotalVisibleMemorySize
# Lets do some math for percent
$MemoryUsed = ($FreeMemory/ $TotalMemory) * 100
$PercentMemoryUsed = $MemoryUsed

$objHostInfo = New-Object System.Object
$objHostInfo | Add-Member -MemberType NoteProperty -Name Name -Value $computer
$objHostInfo | Add-Member -MemberType NoteProperty -Name CPULoadPercent -Value $ComputerCpu
$objHostInfo | Add-Member -MemberType NoteProperty -Name CpuLoadAverage -Value $CpuLoadAverage
$objHostInfo | Add-Member -MemberType NoteProperty -Name MemoryUsedPercent -Value $PercentMemoryUsed

$usedDiskSpaceDrives = ''
$driveLetters = Get-WmiObject Win32_Volume | select DriveLetter

$usedDiskSpaceList = new-object 'System.Collections.Generic.List[System.Object]'

foreach ($driveLetter in $driveLetters)
{
	$drive = Get-WmiObject Win32_Volume | where {$_.DriveLetter -eq $driveLetter.DriveLetter}
	
	if (-Not $drive.Capacity -eq 0)
	{
		$driveCapacity = $drive.Capacity
		$usedDiskSpace = $driveCapacity - $drive.FreeSpace
		$usedDiskSpacePct = [math]::Round(($usedDiskSpace / $drive.Capacity) * 100,1)
		$usedDiskSpaceDrives = $usedDiskSpaceDrives + $drive.Caption + '=' + $usedDiskSpacePct + '#'
		
		$objUsedDiskSpace = New-Object System.Object
		$objUsedDiskSpace | Add-Member -MemberType NoteProperty -Name driveLetter -Value $drive.Caption
		$objUsedDiskSpace | Add-Member -MemberType NoteProperty -Name usedDiskSpace -Value $usedDiskSpace
		$objUsedDiskSpace | Add-Member -MemberType NoteProperty -Name usedDiskSpacePct -Value $usedDiskSpacePct
		$objUsedDiskSpace | Add-Member -MemberType NoteProperty -Name driveCapacity -Value $driveCapacity
		$objUsedDiskSpaceSO = $objUsedDiskSpace | Select-Object driveLetter, driveCapacity, usedDiskSpace, usedDiskSpacePct
		$objUsedDiskSpaceElem = @{driveLetter=$drive.Caption;driveCapacity=$driveCapacity;usedDiskSpace=$usedDiskSpace;usedDiskSpacePct=$usedDiskSpacePct}
		$usedDiskSpaceList.Add($objUsedDiskSpaceElem)
	}
}

# Lets throw them into an object for outputting
$objHostInfo | Add-Member -MemberType NoteProperty -Name usedDiskSpaceDrives -Value $usedDiskSpaceList

$objHostInfoStr = 'ComputerCpu=' + $ComputerCpu + ';CpuLoadAverage=' + $CpuLoadAverage + ';PercentMemoryUsed=' + $PercentMemoryUsed + ';usedDiskSpaceDrives={' + $usedDiskSpaceDrives + '}'

$Processes = Get-Process | Sort-Object CPU -desc | Select-Object Name, Id, Path, Handles, NPM, PM, WS, CPU, SI, ProcessName, StartTime, @{Name='StartTimeFormat'; Expression={$_.StartTime.ToString('yyyyMMddHHmmss')}} -first 5

$TopMemoryUsage = get-wmiobject WIN32_PROCESS | Sort-Object -Property ws -Descending|select -first 5|Select processname, @{Name='Mem Usage(MB)';Expression={[math]::round($_.ws / 1mb)}},@{Name='ProcessID';Expression={[String]$_.ProcessID}},@{Name='UserID';Expression={$_.getowner().user}}

$NetworkInterfaces = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()
$NetworkInterfacesList = new-object 'System.Collections.Generic.List[System.Object]'
foreach ($NetworkInterface in $NetworkInterfaces)
{
	
	$NetworkInterfaceBytesSent = $NetworkInterface.GetIPv4Statistics().BytesSent
	$NetworkInterfaceBytesReceived = $NetworkInterface.GetIPv4Statistics().BytesReceived
	$NetworkInterfaceBytesTotal = $NetworkInterfaceBytesSent + $NetworkInterfaceBytesReceived
	if (-Not $NetworkInterfaceBytesTotal -eq 0)
	{
		$objNetworkInterfaceInfo = New-Object System.Object
		$objNetworkInterfaceInfo | Add-Member -MemberType NoteProperty -Name Id -Value $NetworkInterface.Id
		$objNetworkInterfaceInfo | Add-Member -MemberType NoteProperty -Name Name -Value $NetworkInterface.Name
		$objNetworkInterfaceInfo | Add-Member -MemberType NoteProperty -Name NetworkInterfaceBytesSent -Value $NetworkInterfaceBytesSent
		$objNetworkInterfaceInfo | Add-Member -MemberType NoteProperty -Name NetworkInterfaceBytesReceived -Value $NetworkInterfaceBytesReceived

		$objNetworkInterfaceInfo = $objNetworkInterfaceInfo | Select-Object Id, Name, NetworkInterfaceBytesSent, NetworkInterfaceBytesReceived
		$NetworkInterfacesList.Add($objNetworkInterfaceInfo)
	}
}

$ProduceLog = @{LogInfo=$objLogInfo;HostInfo=$objHostInfo;ProcessesInfo=$Processes;TopMemoryUsageInfo=$TopMemoryUsage;NetworkInterfaceInfo=$NetworkInterfacesList}
$ProduceLog | ConvertTo-Json -Depth 4 | Out-File $CpuLogFile
exit 1