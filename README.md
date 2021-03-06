![](https://stonepagamentos.visualstudio.com/_apis/public/build/definitions/cbfd0924-0dfc-4480-94df-7a12315920f0/220/badge)
# Install Windows Service VSTS task
A small task to stop a Windows Service that is running on the same machine as the VSTS agent that executes this task.

Useful to use when working with Deployment Groups in VSTS.

## Requirements
- [tfx-cli](https://github.com/Microsoft/tfs-cli)
- [Pester](https://github.com/pester/Pester)
- Powershell v3.0 or higher

## Testing

To run unit tests execute the following powershell command at the test directory:

``` powershell
Invoke-Pester -Script .\tests\InstallWindowsService.Tests.ps1 -CodeCoverage .\InstallWindowsService.ps1
```

## Build and Publish

To upload the task to an VSTS account, use the tfx-cli.

### Login
```
tfx login --service-url https://youraccount.visualstudio.com/DefaultCollection
```
Enter your Personal Access Token.

### Upload task

At the root of repository execute the following command:

```
tfx build tasks upload --task-path src
```

# Contributing

Issues and pull-requests are welcome.
