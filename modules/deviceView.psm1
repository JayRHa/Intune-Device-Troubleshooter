<#
.SYNOPSIS
Helper for Device view
.DESCRIPTION
Helper for Device view
.NOTES
  Author: Jannik Reinhard
#>

########################################################################################
################################### Search  Engine #####################################
########################################################################################
function Search-Device{
    param(  
        [String]$searchString
      )
    if($searchString.Length -lt 2) {
        Get-AllManagedDevicesInList -refreshDeviceList $false
        return
    }
    if($searchString -eq '') { 
        Get-AllManagedDevicesInList -refreshDeviceList $false
        return
    }

    $global:AllDeviceObservableCollection = @()          
    $global:AllDeviceObservableCollection = $global:AllManagedDevices | Where-Object `
        { ($_.DeviceName -like "*$searchString*") -or `
        ($_.DevicePrimaryUser -like "*$searchString*") }

        Add-DevicesToGrid -devices $global:AllDeviceObservableCollection
}

########################################################################################
##################################### All Devices #######################################
########################################################################################
function Get-AllManagedDevices {
    $managedDevices = @()
    $devices = Get-MgDeviceManagementManagedDevice -All -Filter "operatingSystem eq 'windows,macOS'" -Property "azureAdDeviceId,deviceName,managementAgent,ownerType,complianceState,deviceType,userId,userPrincipalName,osVersion,lastSyncDateTime,userPrincipalName,id,deviceRegistrationState,managementState,exchangeAccessState,exchangeAccessStateReason,deviceActionResults,deviceEnrollmentType"

    $devices | ForEach-Object {
        $param = [PSCustomObject]@{
          Id                    = $_.Id
          AzureAdId             = $_.AzureAdDeviceId
          DeviceName            = $_.DeviceName
          DeviceManagedBy       = if($_.ManagementAgent -eq 'MDM'){'Intune'}else{$_.ManagementType}
          DeviceOwnership       = switch ($_.OwnerType) {company {'Corporate'}  personal{'Personal'} Default {$_.OwnerType}}
          DeviceCompliance      = if($_.ComplianceState -eq 'noncompliant'){'Not Compliant'}else{'Compliant'}
          DeviceOS              = switch ($_.DeviceType) {windowsRT {'Windows'}  macMDM{'macOS'} Default {$_.DeviceType}}
          DeviceOSVersion       = $_.OSVersion
          DeviceLastCheckin     = $_.LastSyncDateTime
          DevicePrimaryUser     = $_.UserPrincipalName
        }
        $managedDevices += $param
    }
  
  $global:AllManagedDevices = $managedDevices
  return $global:AllManagedDevices
}

function Get-AllManagedDevicesInList{
    param (
        [boolean]$refreshDeviceList = $true
    )
    
    if(-not $global:auth) {return}
    if(($global:AllDeviceCollection ).Count -eq 0 -or $clearDeviceList) {
        $global:AllDeviceCollection  = @()
        Get-AllManagedDevices | Out-Null
    }
    Add-DevicesToGrid -devices $global:AllManagedDevices
}

function Add-DevicesToGrid{
    param (
        $devices
    )
    $items = @()
    $devices = $devices | Sort-Object -Property DeviceName
    $items += $devices | Select-Object -First $([int]$($WPFComboboxDevicesCount.SelectedItem))

	$WPFDataGridAllDevices.ItemsSource = $items
	$WPFLabelCountDevices.Content = "$($items.count) Devices"
}

########################################################################################
################################### Signle Devices #####################################
########################################################################################
function Get-DeviceData{
    param (
        [Parameter(Mandatory = $true)]
        [String]$deviceId
    )

    $uri = "https://graph.microsoft.com/beta/deviceManagement/manageddevices('"+ $deviceId + "')"
    $device = (Invoke-MgGraphRequest -Method GET -Uri $uri)
    $deviceDetails = (Invoke-MgGraphRequest -Method GET -Uri ($uri+'?$select=id,hardwareinformation,processorArchitecture,physicalMemoryInBytes'))

    $deviceDirectoryId = (Get-MgDevice -Search "DeviceId:$($device.AzureAdDeviceId)" -ConsistencyLevel eventual).Id
    $deviceHash = Get-MgDeviceManagementWindowAutopilotDeviceIdentity | Where-Object {$_.AzureAdDeviceId -eq $device.AzureAdDeviceId}
    $deviceOwner = Get-MgDeviceManagementManagedDeviceUser -ManagedDeviceId $deviceId

    $storage = ""
    if($($device.freeStorageSpaceInBytes)){
        $storageTotal = [math]::Round(($($device.totalStorageSpaceInBytes) / 1GB))
        $storageUsed = $storageTotal - ([math]::Round(($($device.freeStorageSpaceInBytes) / 1GB)))
        $storageProcent = [math]::Round((100 / $storageTotal) * $storageUsed)
        $storage = "$($storageUsed)GB/$($storageTotal)GB ($storageProcent%)"
    }else {
        $storage = "/" 
    }

    # Compliance
    $deviceCompliance = (Get-MgDeviceManagementManagedDeviceCompliancePolicyState -ManagedDeviceId $deviceId) | Where-Object {-not($_.State -eq 'unknown')}
    $deviceCompliance.count
    $compliantCount = ($deviceCompliance | Where-Object{ $_.State -eq 'compliant'}).count
    $noCompliantCount = ($deviceCompliance | Where-Object {$_.State -eq 'nonCompliant'}).count
    $noCompliant =  @(($deviceCompliance | Where-Object {$_.State -eq 'nonCompliant'}).DisplayName)
    $notApplicableCount = ($deviceCompliance | Where-Object {$_.State -eq 'notApplicable'}).count

    # Config Profiles
    $deviceConfigProfiles = Get-MgDeviceManagementManagedDeviceConfigurationState -ManagedDeviceId $deviceId | Where-Object {-not($_.State -eq 'unknown')}
    $configProfileSucceededCount        = (@($deviceConfigProfiles | Where-Object{ $_.State -eq 'compliant'})).count
    $configProfileErrorCount            = (@($deviceConfigProfiles | Where-Object{ $_.State -eq 'error'})).count
    $configProfileError                 = (($deviceConfigProfiles | Where-Object{ $_.State -eq 'error'}).DisplayName)  | Select-Object -Unique
    $configProfileNotApplicableCount    = (@($deviceConfigProfiles | Where-Object{ $_.State -eq 'notApplicable'})).count

    #Apps
    $uri = "https://graph.microsoft.com/beta/users('" + $deviceOwner.id + "')/mobileAppIntentAndStates('" + $deviceId + "')"
    $deviceApps = (Invoke-MgGraphRequest -Method GET -Uri $uri).mobileAppList

    $appInstalledCount  = (@($deviceApps | Where-Object{ $_.installState -eq 'installed'})).count
    $appUnknowCount     = (@($deviceApps | Where-Object{ $_.installState -eq 'unknown'})).count
    $appErrorCount      = (@($deviceApps | Where-Object{ $_.installState -eq 'error'})).count
    $appError           = (($deviceApps | Where-Object{ $_.installState -eq 'error'}).DisplayName)  | Select-Object -Unique

    $device = [PSCustomObject]@{
        Id                      = $deviceId
        AzureAdId               = $device.azureADDeviceId
        AzureAdDirectoryId      = $deviceDirectoryId
        DeviceHashId            = $deviceHash.Id
        Mac                     = $device.ethernetMacAddress

        Hostname                = $device.deviceName
        ManagedDeviceName       = $device.managedDeviceName
        EnrolledDateTime        = $device.enrolledDateTime
        LastSyncDateTime        = $device.lastSyncDateTime
        SerialNr                = $device.serialNumber
        Owner                   = $device.userPrincipalName
        Category                = $device.deviceCategoryDisplayName
        DeviceRegistration      = $device.deviceRegistrationState
        AzureAdRegistered       = $device.azureAdRegistered
        DeviceOwnerType         = $device.managedDeviceOwnerType
        ManagementAgent         = $device.managementAgent
        EnrollmentType          = $device.deviceEnrollmentType
        LostModeState           = $device.lostModeState

        AutopilotEnrollment     = ($device.autopilotEnrolled).ToString()
        EnrollmentProfile       = $device.enrollmentProfileName
        GroupTag                = $deviceHash.groupTag
        AutopilotHashAssignment = $deviceHash.deploymentProfileAssignmentStatus
        AutopilotHashAssignmentDT = $deviceHash.deploymentProfileAssignedDateTime
        PurchaseOrder           = $deviceHash.purchaseOrderIdentifier

        ComplianceState         = $device.complianceState 
        CompliantPolicies       = "$compliantCount/$($compliantCount+$noCompliantCount)"
        UncompliantPolicies     = $noCompliantCount
        NotApplicablePolicies   =  $notApplicableCount 
        UncompliantPoliciesList = $noCompliant

        OwnerName               = $deviceOwner.displayName
        OwnerUpn                = $deviceOwner.userPrincipalName
        OwnerAccountEnabled     = $deviceOwner.accountEnabled
        OwnerPhone              = $deviceOwner.businessPhones[0]
        OwnerEmail              = $deviceOwner.mail
        OwnerId                 = $deviceOwner.id
        OwnerSid                = $deviceOwner.additionalProperties.securityIdentifier
        OwnerCountry            = $deviceOwner.country
        OwnerDepartment         = $deviceOwner.department
        OwnerIntuneLicense      = if((($deviceOwner.assignedPlans | Where-Object {$_.servicePlanId -eq 'c1ec4a95-1f05-45b3-a911-aa3fa01094f5' -and $_.capabilityStatus -eq "Enabled"}).count) -gt 0){"True"}else{"False"}

        Manufacturer            = $device.manufacturer
        Model                   = $device.model
        OS                      = $device.operatingSystem
        OsVersion               = "$($device.osVersion) ($($device.skuFamily))"
        OsLanguage              = $deviceDetails.hardwareInformation.operatingSystemLanguage
        BiosVersion             = $deviceDetails.hardwareInformation.systemManagementBIOSVersion
        Hardwaretype            = $device.chassisType
        Storage                 = $storage
        StorageProcent          = $storageProcent
        Ram                     = "$(($deviceDetails.physicalMemoryInBytes / 1GB))GB"
        IsEncrypted             = ($device.isEncrypted).ToString()

        ActiveMalware           = ($device.windowsActiveMalwareCount).ToString()
        RemediatedMalware       = ($device.windowsRemediatedMalwareCount).ToString()


        IpAddresses             = $deviceDetails.hardwareInformation.wiredIPv4Addresses
    
        ManagementCert          = $device.managementCertificateExpirationDate
        ProfileSucceeded        = "$configProfileSucceededCount/$($configProfileSucceededCount+$configProfileErrorCount)"  
        ProfileError            = $configProfileErrorCount
        ProfileNotApplicable    = $configProfileNotApplicableCount
        ProfilesErrorList       = $configProfileError

        AppsInstalled           = "$appInstalledCount/$($appInstalledCount+$appUnknowCount+$appErrorCount)"  
        AppsUnknow              = $appUnknowCount
        AppsError               = $appErrorCount
        AppsErrorList           = $appError

      }

    $global:SelectedDeviceDetails = $device
    return $device
}

function Get-DeviceRecommendation {
    $global:recommendations = $null
    $global:recommendations = [System.Data.DataTable]::New()
    [void]$global:recommendations.Columns.AddRange(@('Recommendation', 'RecommendationAction', 'RecommendationActionVisibility'))
    $global:recommendations.primarykey = $global:recommendations.columns['Recommendation']
    $WPFDataGridRecommendation.ItemsSource = $global:recommendations.DefaultView

    if($global:SelectedDeviceDetails.ProfileError -gt 0){$global:SelectedDeviceDetails.ProfilesErrorList | ForEach-Object {[void]$global:recommendations.Rows.Add("Error state for Config Profile: $_ ", "Check config profiles",'Visible')}}
    if($global:SelectedDeviceDetails.UncompliantPolicies -gt 0){$global:SelectedDeviceDetails.UncompliantPoliciesList | ForEach-Object {[void]$global:recommendations.Rows.Add("Uncompliant Policy: $_ ", "Check compliance policy",'Visible')}}
    if($global:SelectedDeviceDetails.AppsError -gt 0){$global:SelectedDeviceDetails.AppsErrorList | ForEach-Object {[void]$global:recommendations.Rows.Add("App in error state: $_ ", "Check Apps",'Visible')}}
    if($global:SelectedDeviceDetails.AppsUnknow -gt 0) {[void]$global:recommendations.Rows.Add("$($global:SelectedDeviceDetails.AppsUnknow) App(s) in an unknow state", "Check Apps",'Hidden')}


    if($global:SelectedDeviceDetails.StorageProcent -gt 80) {[void]$global:recommendations.Rows.Add("Device low of storage: $($global:SelectedDeviceDetails.Storage)", "",'Hidden')}
    if($global:SelectedDeviceDetails.OwnerIntuneLicense -eq 'False') {[void]$global:recommendations.Rows.Add("Device owner has no intune license: $($global:SelectedDeviceDetails.OwnerUpn)", "Assign a intune license",'Visible')}

    if($global:SelectedDeviceDetails.IsEncrypted -eq 'False') {[void]$global:recommendations.Rows.Add("Device is not encrypted", "",'Hidden')}
    if(-not ($global:SelectedDeviceDetails.LostModeState -eq 'disabled')) {[void]$global:recommendations.Rows.Add("Device is in the lost mode", "",'Hidden')}
    if($global:SelectedDeviceDetails.ActiveMalware -gt 0) {[void]$global:recommendations.Rows.Add("Active maleware on the device", "",'Hidden')}

}

### Remediations
function Get-RemediationScripts{
    param (
        [Parameter(Mandatory = $true)]
        [String]$deviceId
    )

    $allRemediationScripts = @()

    $remediationScripts = Get-MgDeviceManagementDeviceHealthScript -ExpandProperty "assignments,runSummary"
    $remediationScripts | ForEach-Object{
        $uri = 'https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts/'+ $_.Id  +'/deviceRunStates?$expand=managedDevice&$filter='
        $assignment = (Invoke-MgGraphRequest -Method GET -Uri $uri).Value
        
        $assignedToDevice = "Not Assigned to device"
        $detectionState = ""
        $remediationState = ""

        if(($assignment | Where-Object {$_.managedDevice.id -eq $deviceId}).count -gt 0){
            $assignedToDevice   = "Assigned to device"
            $detectionState     = ($assignment | Where-Object {$_.managedDevice.id -eq $deviceId}).detectionState
            $remediationState   = ($assignment | Where-Object {$_.managedDevice.id -eq $deviceId}).remediationState
        }

        $remediationScript = [PSCustomObject]@{
            Id                              = $_.Id
            RemediationScriptName           = $_.DisplayName
            RemediationAuthor               = $_.Publisher
            RemediationStatus               = if($_.Assignments.count -gt 0){"Active"}else{"Not deployed"}
            RemediationAssignedToDevice     = $assignedToDevice
            RemediationDetectionStatus      = $detectionState
            RemediationRemediationStatus    = $remediationState
            Assignements                    = $_.assignments
            GroupName                       = ($global:RemediationGroupPrefix + $_.DisplayName).Replace(" ","")
        }
        $allRemediationScripts += $remediationScript

    }
    return $allRemediationScripts
}

function Add-RemediationsToGrid{
    param (
        [Parameter(Mandatory = $true)]
        [String]$deviceId
    )

    $remediationScrips = Get-RemediationScripts -deviceId $deviceId

    $items = @()
    $remediationScrips =$remediationScrips | Sort-Object -Property RemediationScriptName
    $items += $remediationScrips | Select-Object -First $([int]$($WPFComboboxDevicesCount.SelectedItem))
	$WPFListViewRemediation.ItemsSource = $items
}

function Start-SelectedRemediation{
    param (
        [Parameter(Mandatory = $true)]
        $remediation
    )

    $groupAssigned = $false
    $groupId = (Get-MgGroup -Property "id" -Search "displayName:$($remediation.GroupName)" -Top 1 -ConsistencyLevel eventual) 
    if(-not($groupId)){
        Add-MgtGroup -groupName ($remediation.GroupName) -groupDescription "Auto generated group from Intune Device Troubleshooter"
    }else{
        $remediation.GroupIds | ForEach-Object {
            $assignedGroupId = $_.target.AdditionalProperties.groupId
            if($assignedGroupId){
                $groupName = (Get-MgGroup -GroupId $assignedGroupId -Property "displayName" ).DisplayName
                if($groupName -eq $remediation.GroupName){
                    $groupAssigned = $true
                }
            }
        }
    }

    $groupId = (Get-MgGroup -Property "id" -Search "displayName:$($remediation.GroupName)" -Top 1 -ConsistencyLevel eventual).Id
    $deviceDirectoryId = (Get-MgDevice -Search "DeviceId:$($global:SelectedDevice.AzureAdId)" -ConsistencyLevel eventual).Id

    Add-DirectoryItemToGroup -groupId $groupId -item $deviceDirectoryId

    if(-not($groupAssigned)){
        Add-GroupToRemediationScrip -groupId $groupId -scripId $remediation.id
    }
}

function Add-MgtGroup{
    param (
        [Parameter(Mandatory = $true)]
        [String]$groupName,
        [String]$groupDescription = $null
    )
    $bodyJson = @'
    {
        "displayName": "",
        "groupTypes": [],
        "mailEnabled": false,
        "mailNickname": "NotSet",
        "securityEnabled": true
    }
'@ | ConvertFrom-Json

    $bodyJson.displayName = $groupName

    if($groupDescription){
        $bodyJson | Add-Member -NotePropertyName description -NotePropertyValue $groupDescription
    } 
    
    $bodyJson = $bodyJson | ConvertTo-Json
    New-MgGroup -BodyParameter $bodyJson
}

function Add-DirectoryItemToGroup {
    param(
        [Parameter(Mandatory = $true)]  
        $groupId,
        [Parameter(Mandatory = $true)]  
        $item
    )

    $params = @{
        "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$item"
    }

    try{
        New-MgGroupMemberByRef -GroupId $groupId -BodyParameter $params
    }catch{}
}

function Add-GroupToRemediationScrip {
    param(
        [Parameter(Mandatory = $true)]  
        $groupId,
        [Parameter(Mandatory = $true)]  
        $scripId      
    )

    $assignmentsObj = @"
    {
        "deviceHealthScriptAssignments": []
    }
"@ | ConvertFrom-Json

    $assignment = @"
{
    "@odata.type": "#microsoft.graph.deviceHealthScriptAssignment",
    "target": {
        "@odata.type": "#microsoft.graph.groupAssignmentTarget",
        "deviceAndAppManagementAssignmentFilterId": "00000000-0000-0000-0000-000000000000",
        "groupId": ""
    },
    "runRemediationScript": true,
    "runSchedule": {
        "@odata.type": "#microsoft.graph.deviceHealthScriptRunOnceSchedule",
        "interval": 1,
        "useUtc": true,
        "time": "1:0:0",
        "date": ""
    }
}
"@ | ConvertFrom-Json

    $assignment.target.groupId = $groupId
    $assignment.runSchedule.date = "$((Get-Date).ToString('yyyy-MM-dd'))"

    $assignmentsObj.deviceHealthScriptAssignments += $assignment

    $uri = 'https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts/' + $scripId +'?$expand=assignments'
    $currentAssignments = (Invoke-MgGraphRequest -Method GET -Uri $uri).assignments
    $currentAssignments = $currentAssignments | ConvertTo-Json -Depth 5 | ConvertFrom-Json

    if($currentAssignments.count -gt 0){
        $assignmentsObj.deviceHealthScriptAssignments += $currentAssignments
    }

    Write-Host ($assignmentsObj | ConvertTo-Json -Depth 5)

    $uri = "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts/"+ $scripId +"/assign"
    Invoke-MgGraphRequest -Method POST -ContentType 'application/json' -Uri $uri -Body ($assignmentsObj | ConvertTo-Json -Depth 5)
}