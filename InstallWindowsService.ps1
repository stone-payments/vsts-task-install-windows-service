[CmdletBinding()]
param([switch]$dotSourceOnly)

function Install-WindowsService ($winServiceName, $installCommand, $workingDir) {

    Write-Host "ServiceName: $winServiceName"
  
    # Mount service filter criteria.
    $serviceSearchFilter = "Name='$winServiceName'"
    # Get installed service
    $installedService = Get-WmiObject -Class Win32_Service -Filter $serviceSearchFilter
  
    # If service is already installed remove previous version.
    if($installedService -ne $null){
  
      # Try delete service.
      Write-Host "Deleting service..."
      $deleteResult = $installedService.Delete()
  
      # Verify if service was deleted.
      if($deleteResult.ReturnValue -ne 0){
        throw "Service $winServiceName cannot be removed"
      }
    }
  
    # Mount install command
    if(-not ($installCommand.ToString().Contains($workingDir))){
      $installCommand = "$workingDir\$installCommand"
    }
  
    $lastec = ""
    $return = ""
  
    "Install command: $installCommand"
    # Run install command
    try {
      ## Executes the command and throws the stdout and stderr to a String  
      $return = iex  "$installCommand 2>&1"
      $lastec = $LASTEXITCODE
  
      if ($lastec -ne 0) {
        Write-Host "Error installing."
        throw "$return"
      }
      else {
        Write-Host "Install succeeded."
      }
    }
    catch {
      Write-Output "Error installing!"
      Write-Output "$return"
    }
  }

  function Set-ServiceAccount ($account,$password,$serviceName){
    $serviceFilter = "name='$serviceName'"

    $wmiService = gwmi win32_service -filter $serviceFilter
    if ($wmiService) {
        Stop-Service $serviceName
        $wmiService.Change($null,$null,$null,$null,$null,$null,$account,$password,$null,$null,$null)
        try{
            Start-Service $serviceName
        }catch{
            throw "Service not able to start after service account change. Verify by trying run the service executable/command manually."
        }
        $wmiService = gwmi win32_service -filter $serviceFilter
        
        if($wmiService.StartName -ne $account){
            throw "After trying to change the service account, it does not match the provided one. Failed to change the service account."
        }
    }else{
        throw "The service $serviceName was not found. Could not change the service account."
    }
}
function Main () {
    # For more information on the VSTS Task SDK:
    # https://github.com/Microsoft/vsts-task-lib
    Trace-VstsEnteringInvocation $MyInvocation
    try {
        
        $serviceName = Get-VstsInput -Name "ServiceName" -Require
        $installCommand = Get-VstsInput -Name "InstallCommand" -Require
        $workingDir = Get-VstsInput -Name "WorkingDir" -Require
        $serviceUser = Get-VstsInput -Name "ServiceUser" -Require
        $serviceAccount = Get-VstsInput -Name "ServiceAccount"
        $servicePassword = Get-VstsInput -Name "ServicePassword"

        $service = Get-Service $serviceName

        Install-WindowsService  $service.name $installCommand $workingDir

        if($serviceUser -ne "Default"){
            Set-ServiceAccount $serviceAccount $servicePassword $service.name
        }

    } finally {
        Trace-VstsLeavingInvocation $MyInvocation
    }
}

if($dotSourceOnly -eq $false){
    Main
}
