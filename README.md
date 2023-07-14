# Article: Dynamically Adding Storage to a VM in VMware and the Windows Level Using PowerShell

Managing storage in a virtual environment is a common task for system administrators. In VMware, one of the tasks you might encounter is the need to add more storage to a Virtual Machine (VM) without downtime. Traditionally, this would involve several steps, both on the VMware side and within the Windows VM itself. However, with a well-written PowerShell script, you can simplify this task to a mere few clicks.

This article will examine a PowerShell function, `Invoke-WindowsVMDiskSpace`, designed to dynamically add storage to a VM in VMware at the virtual host level and the Windows level.

## Understanding the PowerShell Function

The `Invoke-WindowsVMDiskSpace` function is designed to add disk space to a VM's hard disk at both the virtual host level (managed by VMware) and the Windows level (inside the VM's operating system). It achieves this by using the VMware PowerCLI to interact with the VMware vSphere environment and native Windows PowerShell cmdlets to communicate with the Windows OS inside the VM.

The function accepts parameters for the VMware server, the name of the VM, the size of the new disk to be added, and the Windows drive letter to which the new storage should be allocated. Additionally, it includes switches for `ResultsOnly` and `Test`, which allow for more granular control of its operation.

An internal function `Invoke-Logger` is also included, which is responsible for logging all activities performed by the main function. It accepts parameters for the log message, the log file location, and switches to determine the output format.

## How the Function Works

Here's a high-level view of how this function works:

1. It first loads the VMware PowerCLI module and sets the default server mode to Multiple.
2. The function then asks for the credentials to connect to the vCenter Server.
3. It checks if the VM with the provided name exists in the vCenter.
4. It retrieves the Windows disk drives' information using the Win32_DiskDrive WMI class and matches them with the VMware level hard disks.
5. If a snapshot exists for the VM, the script provides an option to delete it since a VM's disk cannot be modified when a snapshot exists.
6. After ensuring there's no snapshot, the function proceeds to add the specified amount of disk space to the VM's hard disk in vCenter.
7. It then logs into the Windows VM and initiates a disk rescan using the DiskPart utility.
8. Finally, it extends the chosen Windows partition with the new disk space.

The function `Invoke-Logger` logs all these steps, which can be crucial for auditing and troubleshooting.

## Benefits of Using This PowerShell Function

This function offers a myriad of benefits, including:

1. **Automation**: The function automates a task that would otherwise require manual work in both the VMware vSphere client and within the VM's operating system.

2. **Speed**: Since the process is automated, the function can perform the task much faster than a human operator.

3. **Error Reduction**: By automating the process, the function helps to reduce the potential for human error. For example, it ensures the task won't be executed if a snapshot exists, which could potentially corrupt the VM's data.

4. **Dynamic Storage Addition**: The function enables dynamic storage addition, allowing storage to be added while the VM is running with no need for downtime.

## Using the Function

To use the function, you would typically dot-source it in a PowerShell session and then call the function with the required parameters. For instance:

```powershell
. .\Invoke-WindowsVMDiskSpace.ps1
Invoke-WindowsVMDiskSpace -VMserver 'vCenter01' -computername 'VM01' -NewDiskSize '50' -WindowsDriveLetter 'D:'
```

This would add 50GB of disk space to the D: drive of the VM named 'VM01' on the vCenter server 'vCenter01'.

In conclusion, the `Invoke-WindowsVMDiskSpace` PowerShell function is an invaluable tool for dynamically adding storage to a VM in VMware at the virtual host level and the Windows level. By leveraging this function, administrators can ensure a smoother, faster, and more accurate process for managing VM storage.
