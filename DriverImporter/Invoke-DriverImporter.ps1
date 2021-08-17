$VerbosePreference = 'Continue'
Import-Module (Join-Path (Split-Path $env:SMS_ADMIN_UI_PATH -Parent) 'ConfigurationManager.psd1')

# Customize these bits. Will make this a function later.
[IO.DirectoryInfo] $DriverRoot = '\\CMServer\PkgSrc\Drivers'
$DriverMake = 'Dell'
$DriverModel = 'Latitude'
$DriverPackage = '5310-WIN10-A06-T0HKM'

Push-Location SAT:
$driverCategories = (@($DriverMake, $DriverModel, $DriverPackage) -join '-').ToUpper().Split('- ') | Select-Object -Unique
[Collections.ArrayList] $administrativeCategoryNames = @()
foreach ($driverCategory in $driverCategories) {
    $administrativeCategoryNames.Add($driverCategory) | Out-Null
    try {
        $result = New-CMCategory -CategoryType 'DriverCategories' -Name $driverCategory
        Write-Host ('[CMDriverImporter] Driver Category created: {0}' -f $driverCategory)
        Write-Verbose ('[CMDriverImporter] Driver Category created: {0}' -f ($result | Out-String))
    } catch [System.ArgumentException] {
        if ($_.Exception.Message -eq 'An object with the specified name already exists.') {
            Write-Verbose ('[CMDriverImporter] Driver Category already exists: {0}' -f $driverCategory)
        } else {
            Throw $_.Exception
        }
    }
}
Pop-Location

[IO.DirectoryInfo] $cmDriverPackagePath = [IO.Path]::Combine($DriverRoot.Parent.FullName, 'DriverPackages', $DriverPackage)

$cmDriverPackage = @{
    Name = $DriverPackage
    Path = $cmDriverPackagePath.FullName
    Description = $DriverPackage.Split('-')[0]
    DriverManufacturer = $DriverMake
    DriverModel = $DriverModel
}

New-Item -ItemType 'Directory' -Name $cmDriverPackagePath.Name -Path $cmDriverPackagePath.Parent.FullName -Force | Out-Null

Push-Location SAT:
Write-Verbose ('[CMDriverImporter] New-CMDriverPackage: {0}' -f ($cmDriverPackage | ConvertTo-Json))
try {
    $driverPackageObject = New-CMDriverPackage @cmDriverPackage
    Write-Host ('[CMDriverImporter] Driver Package created: {0}' -f $cmDriverPackage.Name)
    Write-Verbose ('[CMDriverImporter] Driver Package created: {0}' -f ($result | Out-String))
} catch [System.ArgumentException] {
    if ($_.Exception.Message -eq 'An object with the specified name already exists.') {
        Write-Verbose ('[CMDriverImporter] Driver Package already exists: {0}' -f $cmDriverPackage.Name)
        $driverPackageObject = Get-CMDriverPackage -Name $DriverPackage -Fast
    } else {
        Throw $_.Exception
    }
}
Pop-Location


[IO.DirectoryInfo] $cmDriverPath = [IO.Path]::Combine($DriverRoot.FullName, $DriverMake, $DriverModel, $DriverPackage)

Push-Location SAT:
$cmDriver = @{
    Path = $cmDriverPath.FullName
    AdministrativeCategoryName = $administrativeCategoryNames
    DriverPackage = $driverPackageObject
    EnableAndAllowInstall = $true
    ImportDuplicateDriverOption = 'AppendCategory'
    ImportFolder = $true
    SupportedPlatform = Get-CMSupportedPlatform -MinVersion '10.*' -Platform 'x64' | Where-Object {($_.OSName -eq 'Win NT') -and ($_.DisplayText -like 'All Windows 10*')}
}
Write-Verbose ('[CMDriverImporter] New-CMDriver: {0}' -f ($cmDriver | ConvertTo-Json))
Import-CMDriver @cmDriver
Pop-Location

$cmContentDistribution = @{
    DriverPackageName = $DriverPackage
    DistributionPointGroupName = 'All Dps'
}
Push-Location SAT:
Start-CMContentDistribution @cmContentDistribution
Pop-Location
