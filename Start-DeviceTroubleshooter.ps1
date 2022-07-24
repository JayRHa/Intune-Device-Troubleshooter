<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Start-Deviceroubleshooter
Description:
Helper to troubleshoot Intune device
Release notes:

#> 
###########################################################################################################
############################################ Functions ####################################################
###########################################################################################################
function Get-MessageScreen{
    param (
        [Parameter(Mandatory = $true)]
        [String]$xamlPath
    )
    
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
    Add-Type -AssemblyName PresentationFramework
    [xml]$xaml = Get-Content $xamlPath
    $global:messageScreen = ([Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml)))
    $global:messageScreenTitle = $global:messageScreen.FindName("TextMessageHeader")
    $global:messageScreenText = $global:messageScreen.FindName("TextMessageBody")
    $global:button1 = $global:messageScreen.FindName("ButtonMessage1")
    $global:button2 = $global:messageScreen.FindName("ButtonMessage2")

    $global:messageScreenTitle.Text = "Initializing Device Troubleshooter"
    $global:messageScreenText.Text = "Starting Device Troubleshooter"
    $global:messageScreen.Show() | Out-Null
    [System.Windows.Forms.Application]::DoEvents()
}

function Import-AllModules
{
    foreach($file in (Get-Item -path "$global:Path\modules\*.psm1"))
    {      
        $fileName = [IO.Path]::GetFileName($file) 
        if($skipModules -contains $fileName) { Write-Warning "Module $fileName excluded"; continue; }
    
        $module = Import-Module $file -PassThru -Force -Global -ErrorAction SilentlyContinue
        if($module)
        {
            $global:messageScreenText.Text = "Module $($module.Name) loaded successfully"
        }
        else
        {
            $global:messageScreenText.Text = "Failed to load module $file"
        }
    }
}

###########################################################################################################
############################################## Start ######################################################
###########################################################################################################
# Change
$global:RemediationGroupPrefix = "MDM-Remediation-Trigger-"

# Variables
[array]$global:AllDeviceObservableCollection  = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
[array]$global:AllDeviceCollection = $null
[array]$global:AllManagedDevices = $null

$global:Auth = $false
$global:Path = $PSScriptRoot
$global:SelectedDevice = ""

# Start Start Screen
Get-MessageScreen -xamlPath ("$global:Path\xaml\message.xaml")
$global:messageScreenTitle.Text = "Initializing Device Troubleshooter"
$global:messageScreenText.Text = "Starting Device Troubleshooter"

# Load custom modules
Import-AllModules

#Init 
if (-not (Start-Init)){
    Write-Error "Error while loading the dlls. Exit the script"
    Write-Warning "Unblock all dlls and restart the powershell seassion"
    $global:messageScreen.Hide()
    Exit
}

# Load main windows
$returnMainForm = New-XamlScreen -xamlPath ("$global:Path\xaml\ui.xaml")
$global:formMainForm = $returnMainForm[0]
$xamlMainForm = $returnMainForm[1]
$xamlMainForm.SelectNodes("//*[@Name]") | % {Set-Variable -Name "WPF$($_.Name)" -Value $formMainForm.FindName($_.Name)}
$global:formMainForm.add_Loaded({
    $global:messageScreen.Hide()
    $global:formMainForm.Activate()
})

# Init User interface
$global:messageScreenText.Text = "Load User Interface"
Set-UserInterface

# Load the click actions
$global:messageScreenText.Text = "Load Actions"
Set-UiAction
Set-UiActionButton

# Authentication
$global:messageScreenText.Text = "Login to Microsoft Graph (Auth Windows could be in the backround)"
Set-LoginOrLogout

$global:messageScreenText.Text = "Get all managed devices"
Get-AllManagedDevicesInList | out-null

# Start Main Windows
$global:formMainForm.ShowDialog() | out-null