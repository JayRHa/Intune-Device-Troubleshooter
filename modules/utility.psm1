<#
.SYNOPSIS
Core functions
.DESCRIPTION
Core functions
.NOTES
  Author: Jannik Reinhard
#>

##
function Start-Init {
  #Load dll
  try {
    [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')  				              | out-null
    [System.Reflection.Assembly]::LoadWithPartialName('presentationframework') 				              | out-null
    [System.Reflection.Assembly]::LoadFrom("$global:Path\libaries\MahApps.Metro.dll")       				| out-null
    [System.Reflection.Assembly]::LoadFrom("$global:Path\libaries\ControlzEx.dll")                  | out-null  
    [System.Reflection.Assembly]::LoadFrom("$global:Path\libaries\SimpleDialogs.dll")               | out-null
    [System.Reflection.Assembly]::LoadFrom("$global:Path\libaries\LoadingIndicators.WPF.dll")       | out-null   

  }catch{
    Write-Error "Loading from dll's was not sucessfull:"
    return $false
  }

  # Create temp folder
  if(-not (Test-Path "$global:Path\.tmp")) {
    New-Item "$global:Path\.tmp" -Itemtype Directory
  }
  return $true
}



function Add-XamlEvent{
  param(
    [Parameter(Mandatory = $true)]  
    $object,
    [Parameter(Mandatory = $true)]
    $event,
    [Parameter(Mandatory = $true)]
    $scriptBlock
  )

  try {
      if($object)
      {
          $object."$event"($scriptBlock)
      }
      else 
      {
          $global:txtSplashText.Text = "Event  $($object.Name) loaded successfully"

      }
  }
  catch 
  {
      Write-Error "Failed load event $($object.Name). Error:" $_.Exception
  }
}

function Get-GraphAuthentication{
  if (-not (Get-Module -ListAvailable -Name 'Microsoft.Graph')) {
    try{
      Install-Module Microsoft.Graph -Scope CurrentUser
    }catch{
      Write-Error "Something went wrong during the installation of Microsoft.Graph check https://docs.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0 to install the module"
      return $false
    } 
  }
  
  try {
    Connect-MgGraph -Scopes "User.Read.All","User.Read", "Group.Read.All", "DeviceManagementManagedDevices.PrivilegedOperations.All", "DeviceManagementApps.Read.All", "DeviceManagementConfiguration.Read.All", "DeviceManagementManagedDevices.Read.All"
  } catch {
    Write-Error "Failed to connect to MgGraph"
    return $false
  }
  
  Select-MgProfile -Name "beta"
  return $true
}

function Set-LoginOrLogout{
  if($global:auth){
    Disconnect-MgGraph

    Set-UserInterface
    $global:auth = $false
    [System.Windows.MessageBox]::Show('You are logged out')
    $WPFGridHomeFrame.Visibility = 'Hidden'
    $WPFGridGroupManagement.Visibility = 'Hidden'
    Return
  }


  $connectionStatus = Get-GraphAuthentication
  if(-not $connectionStatus) {
      [System.Windows.MessageBox]::Show('Login Failed')
  }
  
  $global:auth = $true


  $user = Get-MgContext
  $org = Get-MgOrganization
  $upn  = $user.Account

  Write-Host "------------------------------------------------------"	
  Write-Host "Connection to graph success: $Success"
  Write-Host "Connected as: $($user.Account)"
  Write-Host "TenantId: $($user.TenantId)"
  Write-Host "Organizsation Name: $($org.DisplayName)"
  Write-Host "------------------------------------------------------"	
  
  Get-ProfilePicture -upn $upn

  #Set Login menue
  $WPFLableUPN.Content = $user.Account
  $WPFLableTenant.Content = $org.DisplayName

  return 
}

function Get-DecodeBase64Image {
  param (
      [Parameter(Mandatory = $true)]
      [String]$imageBase64
  )
  # Parameter help description
  $objBitmapImage = New-Object System.Windows.Media.Imaging.BitmapImage
  $objBitmapImage.BeginInit()
  $objBitmapImage.StreamSource = [System.IO.MemoryStream][System.Convert]::FromBase64String($imageBase64)
  $objBitmapImage.EndInit()
  $objBitmapImage.Freeze()
  return $objBitmapImage
}


function Get-ProfilePicture {
  param (
      [Parameter(Mandatory = $true)]
      [String]$upn
  )
  $path = "$global:Path\.tmp\$upn.png"
  if (-Not (Test-Path $path)) {
      Get-MgUserPhotoContent -UserId $upn -OutFile $path
  }

  if (Test-Path $path) {
    try{
      $iconButtonLogIn = [convert]::ToBase64String((get-content $path -encoding byte))
      $WPFImgButtonLogIn.source = Get-DecodeBase64Image -ImageBase64 $iconButtonLogIn
      $WPFImgButtonLogIn.Width="35"
      $WPFImgButtonLogIn.Height="35"
    }catch{}
  }
}
########################################################################################
########################################### UI  ########################################
########################################################################################
function New-XamlScreen{
  param (
      [Parameter(Mandatory = $true)]
      [String]$xamlPath
  )
  $inputXML = Get-Content $xamlPath
  [xml]$xaml = $inputXML -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace '^<Win.*', '<Window'
  $reader = (New-Object System.Xml.XmlNodeReader $xaml)

  try {
      $form = [Windows.Markup.XamlReader]::Load( $reader )
  }
  catch {
      Write-Host "Unable to load Windows.Markup.XamlReader. Double-check syntax and ensure .net is installed."
  }
  return @($form, $xaml)
}

Function Get-FormVariables {
  if ($global:ReadmeDisplay -ne $true) {Write-host "If you need to reference this display again, run Get-FormVariables" -ForegroundColor Yellow; $global:ReadmeDisplay = $true}
  Write-host "Found the following interactable elements from our form" -ForegroundColor Cyan
  get-variable WPF*
}

function Show-MessageBoxWindow{
  param (
      [String]$titel="Intune Tool Box",
      [Parameter(Mandatory = $true)]
      [String]$text,
      [String]$button1text="",
      [String]$button2text=""

  )

  if($button1text -eq ""){$global:button1.Visibility = "Hidden"}else{$global:button1.Visibility = "Visible"}
  if($button2text -eq ""){$global:button2.Visibility = "Hidden"}else{$global:button2.Visibility = "Visible"}

  $global:messageScreenTitle.Text = $titel
  $global:messageScreenText = $text
  $global:button1.Content = "Yes"
  $global:button2.Content = "No"
  $global:messageScreen.Show() | Out-Null
}

function Show-MessageBoxInWindow{
  param (
      [String]$titel="Intune Tool Box",
      [Parameter(Mandatory = $true)]
      [String]$text,
      [String]$button1text="",
      [String]$button2text="",
      [String]$messageSeverity="Information"

  )

  $global:message = [SimpleDialogs.Controls.MessageDialog]::new()		    
  $global:message.MessageSeverity = $messageSeverity
  $global:message.Title = $titel
  if($button1text -eq ""){$global:message.ShowFirstButton = $false}else{$global:message.ShowSecondButton = $true}
  if($button2text -eq ""){$message.ShowSecondButton = $false}else{$global:message.ShowSecondButton = $true}
  $global:message.FirstButtonContent = $button1text
  $global:message.SecondButtonContent = $button2text

  $global:message.TitleForeground = "White"
  $global:message.Background = "#FF1B1A19"
  $global:message.Message = $text	
  [SimpleDialogs.DialogManager]::ShowDialogAsync($($global:formMainForm), $global:message)

  $global:message.Add_ButtonClicked({
    $buttonArgs  = [SimpleDialogs.Controls.DialogButtonClickedEventArgs]$args[1]	
    $buttonValues = $buttonArgs.Button
    If($buttonValues -eq "FirstButton")
      {
        return $null
      }
    ElseIf($buttonValues -eq "SecondButton")
      {
                return $null
      }				
  })
  return $null
}
