[CmdletBinding()]
param([switch]$dotSourceOnly)

$win32ServiceErrors =@{
    0="The request was accepted.";
    1="The request is not supported.";
    2="The user did not have the necessary access.";
    3="The service cannot be stopped because other services that are running are dependent on it.";
    4="The requested control code is not valid, or it is unacceptable to the service.";
    5="The requested control code cannot be sent to the service because the state of the service (Win32_BaseService.State property) is equal to 0, 1, or 2.";
    6="The service has not been started.";
    7="The service did not respond to the start request in a timely fashion.";
    8="Unknown failure when starting the service.";
    9="The directory path to the service executable file was not found.";
    10="The service is already running.";
    11="The database to add a new service is locked.";
    12="A dependency this service relies on has been removed from the system.";
    13="The service failed to find the service needed from a dependent service.";
    14="The service has been disabled from the system.";
    15="The service does not have the correct authentication to run on the system.";
    16="This service is being removed from the system.";
    17="The service has no execution thread.";
    18="The service has circular dependencies when it starts.";
    19="A service is running under the same name.";
    20="The service name has invalid characters.";
    21="Invalid parameters have been passed to the service.";
    22="The account under which this service runs is either invalid or lacks the permissions to run the service.";
    23="The service exists in the database of services available from the system.";
    24="The service is currently paused in the system.";
}
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
        $changeResult = $wmiService.Change($null,$null,$null,$null,$null,$null,$account,$password,$null,$null,$null)
        if($changeResult.ReturnValue -ne 0 ){
            throw $win32ServiceErrors.$changeResult.value
        }
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
