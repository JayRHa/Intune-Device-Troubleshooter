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
    $devices = Get-MgDeviceManagementManagedDevice -All -Property "azureAdDeviceId,deviceName,managementAgent,ownerType,complianceState,deviceType,userId,userPrincipalName,osVersion,lastSyncDateTime,userPrincipalName,id,deviceRegistrationState,managementState,exchangeAccessState,exchangeAccessStateReason,deviceActionResults,deviceEnrollmentType"

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
	$WPFListViewAllDevices.ItemsSource = $items
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

    $device = Get-MgDeviceManagementManagedDevice -ManagedDeviceId $deviceId
    $deviceDirectoryId = (Get-MgDevice -Search "DeviceId:$($device.AzureAdDeviceId)" -ConsistencyLevel eventual).Id
    $deviceHash = Get-MgDeviceManagementWindowAutopilotDeviceIdentity -Search "AzureAdDeviceId:$($deviceDirectoryId)"

    $device = [PSCustomObject]@{
        Id                      = $deviceId
        AzureAdId               = $device.AzureAdDeviceId
        AzureAdDirectoryId      = $device.deviceDirectoryId
        DeviceHashId            = $deviceHash.Id
        GroupTag                = $deviceHash.GroupTag
        DeviceName              = $device.DeviceName
        SerialNr                = $device.SerialNumber
        Owner                   = $device.UserPrincipalName
        Category                = $device.DeviceCategoryDisplayName
        DeviceType              = $device.DeviceType
      }

    return $device
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