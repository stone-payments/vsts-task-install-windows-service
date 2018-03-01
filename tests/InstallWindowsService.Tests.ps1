# Find and import source script.
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$systemUnderTest = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
$srcDir = "$here\.."
. "$srcDir\$systemUnderTest" -dotSourceOnly

# Import vsts sdk.
$vstsSdkPath = Join-Path $PSScriptRoot ..\ps_modules\VstsTaskSdk\VstsTaskSdk.psm1 -Resolve
Import-Module -Name $vstsSdkPath -Prefix Vsts -ArgumentList @{ NonInteractive = $true } -Force

Describe "Main" {
    # General mocks needed to control flow and avoid throwing errors.
    Mock Trace-VstsEnteringInvocation -MockWith {}
    Mock Trace-VstsLeavingInvocation -MockWith {}
    Mock Get-VstsInput -ParameterFilter { $Name -eq "ServiceName" } -MockWith { return "MyService" } 
    Mock Get-VstsInput -ParameterFilter { $Name -eq "ServiceBinaryPath" } -MockWith { return "C:\apps\some_service\MyCustomService.exe" }

    Context "Installing a service with installUtils and the default user" {
        # Arrange
        Mock Get-VstsInput -ParameterFilter { $Name -eq "InstallationMode" } -MockWith { return "InstallUtils" }
        Mock Get-VstsInput -ParameterFilter { $Name -eq "ServiceUser" } -MockWith { return "Default" } 
        
        Mock Get-Service -MockWith { return @{"name"="MyService"} }
        Mock Convert-Path -MockWith { return "C:\apps\some_service\MyCustomService.exe" }
        Mock Install-WindowsServiceWithInstallUtils {}

        # Act
        Main
        It "should call Install-WindowsServiceWithInstallUtils" {           
            # Assert
            Assert-MockCalled Install-WindowsServiceWithInstallUtils -ParameterFilter { ($winServiceName -eq "MyService") -and ($serviceBinaryPath -eq "C:\apps\some_service\MyCustomService.exe")  }
        }       
    }
    Context "Installing a service with installUtils and a custom user" {
        # Arrange
        Mock Get-VstsInput -ParameterFilter { $Name -eq "InstallationMode" } -MockWith { return "InstallUtils" }
        Mock Get-VstsInput -ParameterFilter { $Name -eq "ServiceUser" } -MockWith { return "Custom" } 
        Mock Get-VstsInput -ParameterFilter { $Name -eq "ServiceAccount" } -MockWith { return "NewUser" } 
        Mock Get-VstsInput -ParameterFilter { $Name -eq "ServicePassword" } -MockWith { return "NewPassword" } 
        
        Mock Get-Service -MockWith { return @{"name"="MyService"} }
        Mock Convert-Path -MockWith { return "C:\apps\some_service\MyCustomService.exe" }
        Mock Install-WindowsServiceWithInstallUtils {}
        Mock Set-ServiceAccount{}

        # Act
        Main
        It "should call Install-WindowsServiceWithInstallUtils" {           
            # Assert
            Assert-MockCalled Install-WindowsServiceWithInstallUtils -ParameterFilter { ($winServiceName -eq "MyService") -and ($serviceBinaryPath -eq "C:\apps\some_service\MyCustomService.exe")  }
        }
        
        It "should call Set-ServiceAccount with custom user credentials"{
            # Assert
            Assert-MockCalled Set-ServiceAccount -ParameterFilter { ($account -eq "NewUser") -and ($password -eq "NewPassword") -and ($serviceName -eq "MyService")  }
        }
    }
    Context "Installing a service with custom command and default user" {
        # Arrange
        Mock Get-VstsInput -ParameterFilter { $Name -eq "InstallationMode" } -MockWith { return "CustomCommand" }
        Mock Get-VstsInput -ParameterFilter { $Name -eq "InstallArguments" } -MockWith { return "--install" }
        Mock Get-VstsInput -ParameterFilter { $Name -eq "ServiceUser" } -MockWith { return "Default" } 
        
        Mock Get-Service -MockWith { return @{"name"="MyService"} }
        Mock Convert-Path -MockWith { return "C:\apps\some_service\MyCustomService.exe" }
        Mock Install-WindowsService {}

        # Act
        Main
        It "should call Install-WindowsService" {           
            # Assert
            Assert-MockCalled Install-WindowsService -ParameterFilter { ($winServiceName -eq "MyService") -and ($installCommand -eq "C:\apps\some_service\MyCustomService.exe --install")  }
        }

    }
    Context "Installing a service with custom command and custom user" {
        # Arrange
        Mock Get-VstsInput -ParameterFilter { $Name -eq "InstallationMode" } -MockWith { return "CustomCommand" }
        Mock Get-VstsInput -ParameterFilter { $Name -eq "InstallArguments" } -MockWith { return "--install" }
        Mock Get-VstsInput -ParameterFilter { $Name -eq "ServiceUser" } -MockWith { return "Custom" } 
        Mock Get-VstsInput -ParameterFilter { $Name -eq "ServiceAccount" } -MockWith { return "NewUser" } 
        Mock Get-VstsInput -ParameterFilter { $Name -eq "ServicePassword" } -MockWith { return "NewPassword" } 
        
        Mock Get-Service -MockWith { return @{"name"="MyService"} }
        Mock Convert-Path -MockWith { return "C:\apps\some_service\MyCustomService.exe" }
        Mock Install-WindowsService {}
        Mock Set-ServiceAccount{}

        # Act
        Main
        It "should call Install-WindowsService" {           
            # Assert
            Assert-MockCalled Install-WindowsService -ParameterFilter { ($winServiceName -eq "MyService") -and ($installCommand -eq "C:\apps\some_service\MyCustomService.exe --install")  }
        }

        It "should call Set-ServiceAccount with custom user credentials"{
            # Assert
            Assert-MockCalled Set-ServiceAccount -ParameterFilter { ($account -eq "NewUser") -and ($password -eq "NewPassword") -and ($serviceName -eq "MyService")  }
        }
    }
    Context "Installing a service with a installation that is not custom or InstallUtils" {
        # Arrange
        Mock Get-VstsInput -ParameterFilter { $Name -eq "InstallationMode" } -MockWith { return "OtherInstallMode" }
        Mock Get-VstsInput -ParameterFilter { $Name -eq "ServiceUser" } -MockWith { return "Default" } 

        Mock Get-Service -MockWith { return @{"name"="MyService"} }
        Mock Convert-Path -MockWith { return "C:\apps\some_service\MyCustomService.exe" }
        Mock Install-WindowsServiceWithInstallUtils {}

        # Act
        
        It "should throw and Exeption" {           
            # Assert
            {Main} | Should -Throw "Invalid installation mode."
        }

    }
}

Describe "Get-InstalledServiceName"{
    
    $serviceName = "MyService"
    $serviceDisplayName = "MyServiceDisplayName"    
    Context "With a service that already exists on the machine, passing the Display name"{

        BeforeEach{
            New-Service -Name $serviceName -DisplayName $serviceDisplayName -BinaryPathName "C:\WINDOWS\System32\svchost.exe -k netsvcs"
        }
        AfterEach{
            $service = Get-WmiObject -Class Win32_Service -Filter "Name='$serviceName'"
            $service.delete()
        }

        It "Should return the service name, not the DisplayName"{
            Get-InstalledServiceName $serviceDisplayName | Should -Be "MyService"              
        }
    }
    Context "With a service that already exists on the machine, passing the name"{

        BeforeEach{
            New-Service -Name $serviceName -DisplayName $serviceDisplayName -BinaryPathName "C:\WINDOWS\System32\svchost.exe -k netsvcs"
        }
        AfterEach{
            $service = Get-WmiObject -Class Win32_Service -Filter "Name='$serviceName'"
            $service.delete()
        }

        It "Should return the service name, not the DisplayName"{
            Get-InstalledServiceName $serviceName | Should -Be "MyService"              
        }
    }
    Context "With a service that does NOT exists on the machine, passing the name"{
        Mock Write-Host {}
        
        It "Should return the service name that was passed"{
            Get-InstalledServiceName $serviceName | Should -Be "MyService"              
        }
        It "Should print a message alerting the user about the missing service"{
            Assert-MockCalled Write-Host -ParameterFilter { $Object -eq "Service $serviceName not found on the current machine, this is probably the first install.Trying to install $serviceName for the first time"}
        }
    }
}

Describe "Install-WindowsServiceWithInstallUtils" {
    $serviceName = "MyService" 
    $serviceBinaryPath = "C:\apps\some_service\MyCustomService.exe"
    Context "When installing a service in a machine that does NOT have installUtills installed"{
        Mock Get-ChildItem -MockWith {$Null}

        It "Should throw an exception"{ 
            {Install-WindowsServiceWithInstallUtils $service $serviceBinaryPath } | Should -Throw "InstallUtil.exe could not be found on the machine. Please make sure that .NET Framework is installed."
        }
    }
    Context "When installing a service in a machine that does have installUtills installed"{
        Mock Get-ChildItem -MockWith {"C:\Windows\Microsoft.NET\Framework64\v4.0.30319\InstallUtil.exe"}
        Mock Install-WindowsService -MockWith {}

        Install-WindowsServiceWithInstallUtils $serviceName $serviceBinaryPath
        It "Should call Install-WindowsService with correct parameters"{ 
            Assert-MockCalled Install-WindowsService -ParameterFilter {($winServiceName -eq "MyService" ) -and ($installCommand -eq "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\InstallUtil.exe C:\apps\some_service\MyCustomService.exe")}        
        }
    }
}
