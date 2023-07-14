Function Invoke-WindowsVMDiskSpace 

{

  [CmdletBinding()]
    param 
    (
        [Parameter(Mandatory=$true)]
        [string]$VMserver,
        [Parameter(Mandatory=$true)]
        [string]$computername,
        [Parameter(Mandatory=$false)]
        [string]$NewDiskSize,
        [Parameter(Mandatory=$false)]
        [string]$WindowsDriveLetter,
        [Parameter(Mandatory=$false)]
        [switch]$ResultsOnly,
        [Parameter(Mandatory=$false)]
        [Switch]$Test
    )

Function Invoke-Logger {


    [CmdletBinding()]
    param 
    (
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [Parameter(Mandatory=$true)]
        [string]$LogFile,
        [Parameter(Mandatory=$false)]
        [Switch]$ShowOutput,
        [Parameter(Mandatory=$false)]
        [Switch]$SaveToCSV,
        [Parameter(Mandatory=$false)]
        [Switch]$ShowError,
        [Parameter(Mandatory=$false)]
        [Switch]$ShowWarning
        
    )
        $date = Get-Date -UFormat "%m/%d/%Y %H:%M:%S"
        $Global:logfile = "$env:USERPROFILE\Set-WindowsVMDiskSpace.log"
        Add-Content $LogFile -Value "$date - $Message"
        if ($ShowOutput)
        {$ShowOutput = Write-Host $Message -ForegroundColor Green }
        if ($ShowError)
        {$ShowError = Write-Host $Message -ForegroundColor Red }
        if ($ShowWarning)
        {$ShowWarning = Write-Host $Message -ForegroundColor Yellow }
        if ($SaveToCSV){$array = @(); $array += [pscustomobject] @{"computer" = $computer; "Message" = "$Message"; "Date" = "$date" }; $array | Export-Csv -Path "$env:USERPROFILE\Set-WindowsVMDiskSpace.csv" -NoTypeInformation }
        $ErrorActionPreference='stop'
        
}
$ErrorActionPreference='stop'
$Global:logfile = "$env:USERPROFILE\Set-WindowsVMDiskSpace.log"

# Initialize variables

$DiskInfo= @()

Get-Module –ListAvailable VM*| Import-Module

# Set Default Server Mode to Multiple
Set-PowerCLIConfiguration -DefaultVIServerMode Multiple -Confirm:$false | Out-Null
# Connect to vCenter Server(s)



$vmwareadmin = Read-Host "Enter Username" 
$pass = Read-Host "Enter Password" -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass)
$password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
Connect-VIServer -Server $VMserver -Protocol https -User "username" -Password "$password"



## Confirm if the VM can be found
if (($VmView = Get-View -ViewType VirtualMachine -Filter @{“Name” = $computername})) {

$WinDisks = Get-WmiObject -Class Win32_DiskDrive -ComputerName $computername
foreach ($VirtualSCSIController in ($VMView.Config.Hardware.Device | where {$_.DeviceInfo.Label -match “SCSI Controller”})) {
foreach ($VirtualDiskDevice in ($VMView.Config.Hardware.Device | where {$_.ControllerKey -eq $VirtualSCSIController.Key})) {
$VirtualDisk = “” | Select SCSIController, DiskName, SCSI_Id, DiskFile, DiskSize, WindowsDisk, WindowsDiskDriveLetter, WindowsDiskDrivePartition
$VirtualDisk.SCSIController = $VirtualSCSIController.DeviceInfo.Label
$VirtualDisk.DiskName = $VirtualDiskDevice.DeviceInfo.Label
$VirtualDisk.SCSI_Id = “$($VirtualSCSIController.BusNumber) : $($VirtualDiskDevice.UnitNumber)”
$VirtualDisk.DiskFile = $VirtualDiskDevice.Backing.FileName
$VirtualDisk.DiskSize = $VirtualDiskDevice.CapacityInKB * 1KB / 1GB
# Match disks based on SCSI ID
$DiskMatch = $WinDisks | ?{($_.SCSIPort – 2) -eq $VirtualSCSIController.BusNumber -and $_.SCSITargetID -eq $VirtualDiskDevice.UnitNumber}
if ($DiskMatch){

$VirtualDisk.WindowsDisk = “Disk $($DiskMatch.Index)”
$VirtualDisk.WindowsDiskDriveLetter = $DiskMatch | % {
        gwmi -ComputerName $computername -Query "ASSOCIATORS OF {Win32_DiskDrive.DeviceID=`"$($_.DeviceID.replace('\','\\'))`"} WHERE AssocClass = Win32_DiskDriveToDiskPartition"} |  %{ gwmi -ComputerName $computername -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID=`"$($_.DeviceID)`"} WHERE AssocClass = Win32_LogicalDiskToPartition"} | %{ $_.deviceid} 
$VirtualDisk.WindowsDiskDrivePartition = $DiskMatch | % {
        $a = $_.DeviceID.Replace("\", "\\")
        gwmi -ComputerName $computername -query "Associators of {Win32_DiskDrive.DeviceID=""$a""} WHERE AssocClass = Win32_DiskDriveToDiskPartition" } 

 }

else {Write-Host “No matching Windows disk found for SCSI id $($VirtualDisk.SCSI_Id)”}
$DiskInfo += $VirtualDisk
}
}
Invoke-Logger -Message "Matching Widnows Disk Drives with VMWARE Level Harddisk" -LogFile $logfile -ShowOutput
$DiskInfo 

if (!$ResultsOnly)
{

$SelectedDisk = $DiskInfo | ? {$_.WindowsDiskDriveLetter -match "$WindowsDriveLetter"}
$SelectedDiskDriveLetter = $SelectedDisk.WindowsDiskDriveLetter
$SelectedDiskFilename = $SelectedDisk.DiskFile
$SelectedDiskNumber = $SelectedDisk.WindowsDisk
$SelectedDiskNumber = $SelectedDiskNumber.split() | select -Last 1
$SelectedDiskID = $SelectedDisk.SCSI_Id

Invoke-Logger -Message "The Following Virtual Disk will be configured for $computername" -LogFile $logfile -ShowOutput
$SelectedDisk | Select WindowsDiskDriveLetter, WindowsDisk, SCSI_Id, DiskSize, DiskFile 


$snapshot = Get-VM -Name $computername | Get-Snapshot | select *
if (!$snapshot) 

{




Invoke-Logger -Message "Adding $NewDiskSize GB to $SelectedDiskFilename on VM $computername" -LogFile $logfile -ShowOutput
$VMDiskSize = Get-HardDisk -VM $computername |? {$_.filename -match [regex]::escape($SelectedDiskFilename)} |  Select-Object -ExpandProperty CapacityGB 
Get-HardDisk -vm $computername | ? {$_.Filename -match [regex]::escape($SelectedDiskFilename)} | Set-HardDisk -CapacityGB ($VMDiskSize + $NewDiskSize) -Confirm:$false -Verbose

}
else 

{

Invoke-Logger -Message "This VM has a Snapshot and the Virtual Drive $SelectedDiskFilename cannot be modified" -LogFile $logfile -ShowError
Invoke-Logger -Message "See Below VM Snapshot details" -LogFile $logfile -ShowError
$snapshot

Write-Host "Would you like to remove snapshot from $computername ?" -ForegroundColor Yellow
 $reults = Read-Host " ( Y / N ) " 
 Switch ($reults)
 {
 
 Y 
 
 {

 Get-vm -Name $computername | Get-Snapshot | Remove-Snapshot -Confirm:$false -ErrorAction SilentlyContinue

 do 
{
Invoke-Logger -Message "Removing snapshot from $computername...." -LogFile $logfile -ShowOutput
sleep -Seconds 20
$snapshot = Get-VM -Name $computername | Get-Snapshot | select *
} 
until (!$snapshot)

Invoke-Logger -Message "Adding $NewDiskSize GB to $SelectedDiskFilename on VM $computername" -LogFile $logfile -ShowOutput
$VMDiskSize = Get-HardDisk -VM $computername |? {$_.filename -match [regex]::escape($SelectedDiskFilename)} |  Select-Object -ExpandProperty CapacityGB 
Get-HardDisk -vm $computername | ? {$_.Filename -match [regex]::escape($SelectedDiskFilename)} | Set-HardDisk -CapacityGB ($VMDiskSize + $NewDiskSize) -Confirm:$false -Verbose

}
 N {break}
 Default {break}

 }



 }






Invoke-Logger -Message "Updating new disk information on Windows for $computername" -LogFile $logfile -ShowOutput

sleep -Seconds 3
Invoke-WmiMethod -Path win32_process -Name create -ArgumentList {cmd.exe /k echo rescan | diskpart } -ComputerName $computername -Impersonation 3 -EnableAllPrivileges
Invoke-Logger -Message "Extending Windows partition with $NewDiskSize GB on $SelectedDiskDriveLetter Drive for $computername" -LogFile $logfile -ShowOutput

Invoke-Logger -Message "$computername Disk Letter $SelectedDiskDriveLetter ID = $id" -Logfile $logfile -Showoutput 

$searchLetter = $SelectedDiskDriveLetter -replace ':'

$listVolcommand = @"
cmd.exe /c "echo list Volume"  | diskpart  >> c:\DiskPartvollog.log
"@

Invoke-WmiMethod -Path win32_process -Name create -ArgumentList ($listVolcommand) -ComputerName "$computername"
sleep 10
$Results = Get-Content -Path "\\$computername\c$\DiskPartvollog.log"

if ($results -match "volume 1     $searchLetter") {Write-Host "Found Match $searchLetter drive is Volumne 1; $Matches"; $volumeID = "1"}
elseif ($results -match "volume 2     $searchLetter") {Write-Host "Found Match $searchLetter drive is Volumne 2; $Matches"; $volumeID = "2"}
elseif ($results -match "volume 3     $searchLetter") {Write-Host "Found Match $searchLetter drive is Volumne 3; $Matches"; $volumeID = "3"}
elseif ($results -match "volume 4     $searchLetter") {Write-Host "Found Match $searchLetter drive is Volumne 4; $Matches"; $volumeID = "4"}
elseif ($results -match "volume 5     $searchLetter") {Write-Host "Found Match $searchLetter drive is Volumne 5; $Matches"; $volumeID = "5"}
elseif ($results -match "volume 6     $searchLetter") {Write-Host "Found Match $searchLetter drive is Volumne 6; $Matches"; $volumeID = "6"}
elseif ($results -match "volume 7     $searchLetter") {Write-Host "Found Match $searchLetter drive is Volumne 7; $Matches"; $volumeID = "7"}
else {Invoke-Logger -Message "Unable to retrive Volume Number for Drive on $vmname" -LogFile $logfile -ShowError;break}
Write-Host $volumeID

$logdate = Get-Date -UFormat "%m.%d.%Y-%H.%M.%S"
$Extendcommand = @"
cmd.exe /c "(echo List Volume && echo Select Volume $volumeID && echo extend)"  | diskpart  >> c:\DiskPartlog_$logdate.log
"@

Invoke-WmiMethod -Path win32_process -Name create -ArgumentList ($Extendcommand) -ComputerName $computername


do {
Write-Host "Command sent to remote computer $computername, Waiting for logfile"
sleep 5
}
until (Get-Content -Path "\\$computername\c$\DiskPartlog_$logdate.log" -ErrorAction SilentlyContinue )
Get-Content -Path "\\$computername\c$\DiskPartlog_$logdate.log"


}


}

else {Write-Host “VM $computername Not Found”}


}

 
 
