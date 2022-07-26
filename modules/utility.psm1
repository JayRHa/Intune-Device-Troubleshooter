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
    $graphLogin = Connect-MgGraph -Scopes "User.Read.All","User.Read", "Group.Read.All", "DeviceManagementManagedDevices.PrivilegedOperations.All", "DeviceManagementApps.Read.All", "DeviceManagementConfiguration.Read.All", "DeviceManagementManagedDevices.Read.All"
    $connection = $?
  } catch {
    Write-Error "Failed to connect to MgGraph"
    return $false
  }
  
  if(-not ($connection)) {return $false}
  $graphLogin =  Select-MgProfile -Name "beta"
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
      return $false
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
  
  $temp = Get-ProfilePicture -upn $upn

  #Set Login menue
  $WPFLableUPN.Content = $user.Account
  $WPFLableTenant.Content = $org.DisplayName

  return $true
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
      Get-MgUserPhotoContent -UserId $upn -OutFile $path -ErrorAction SilentlyContinue
  }

  if (Test-Path $path) {
    try{
      $iconButtonLogIn = [convert]::ToBase64String((get-content $path -encoding byte))
      $WPFImgButtonLogIn.source = Get-DecodeBase64Image -ImageBase64 $iconButtonLogIn
    }catch{}
  } else {
    $defaultPicture = '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'
    $WPFImgButtonLogIn.source = Get-DecodeBase64Image -ImageBase64 $defaultPicture
  }
  $WPFImgButtonLogIn.Width="35"
  $WPFImgButtonLogIn.Height="35"
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
