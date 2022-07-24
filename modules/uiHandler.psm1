<#
.SYNOPSIS
Hadeling UI
.DESCRIPTION
Handling of the WPF UI
.NOTES
  Author: Jannik Reinhard
#>

########################################################################################
###################################### UI Actions ######################################
########################################################################################
function Set-UiActionButton{
    #Home
    Add-XamlEvent -object $WPFButtonHome -event "Add_Click" -scriptBlock {
        Hide-All
        $WPFGridDeviceFinder.Visibility = "Visible"
    }
    
    #About
    Add-XamlEvent -object $WPFButtonAbout -event "Add_Click" -scriptBlock {
        if($WPFGridAbout.Visibility -eq "Visible"){
            Hide-All
            $WPFGridDeviceFinder.Visibility = "Visible"
        }else{
            Hide-All
            $WPFGridAbout.Visibility="Visible"
        }
    }

    Add-XamlEvent -object $WPFButtonAboutWordpress -event "Add_Click" -scriptBlock {Start-Process "https://www.jannikreinhard.com"}
    Add-XamlEvent -object $WPFButtonAboutTwitter -event "Add_Click" -scriptBlock {Start-Process "https://twitter.com/jannik_reinhard"}
    Add-XamlEvent -object $WPFButtonAboutLinkedIn -event "Add_Click" -scriptBlock {Start-Process "https://www.linkedin.com/in/jannik-r/"}

    # Device selection view
    Add-XamlEvent -object $WPFButtonRefreshDeviceOverview -event "Add_Click" -scriptBlock {
        $WPFTextboxSearchBoxDevice.Text = ""
        Get-AllManagedDevicesInList | out-null
    }

    # Device
    Add-XamlEvent -object $WPFButtonSyncDevices -event "Add_Click" -scriptBlock {
        $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$($global:SelectedDevice.Id)')/syncDevice"
        Invoke-MgGraphRequest -Method POST -Uri $uri -Body "{}"
    }
    Add-XamlEvent -object $WPFButtonRestartDevices -event "Add_Click" -scriptBlock {
        $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$($global:SelectedDevice.Id)')/rebootNow"
        Invoke-MgGraphRequest -Method POST -Uri $uri -Body "{}"
    }
    Add-XamlEvent -object $WPFButtonShutdownDevices -event "Add_Click" -scriptBlock {
        $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$($global:SelectedDevice.Id)')/shutDown"
        Invoke-MgGraphRequest -Method POST -Uri $uri -Body "{}"    
    }

    # Remediation
    Add-XamlEvent -object $WPFButtonRefreshRemediations -event "Add_Click" -scriptBlock {Add-RemediationsToGrid -deviceId $($global:SelectedDevice.Id)}
    Add-XamlEvent -object $WPFButtonRunRemediations -event "Add_Click" -scriptBlock {
        if(-not ($WPFListViewRemediation.SelectedIndex -eq -1)){
            if($WPFListViewRemediation.SelectedItem.RemediationAssignedToDevice -eq 'Assigned to device'){Show-MessageBoxInWindow -text "Remediation $($WPFListViewRemediation.SelectedItem.RemediationScriptName) already assigned to the device" -button1text "Ok"}
            else{
                Show-MessageBoxInWindow -text "Are you shure that you want to assigne the script. This will create a new AAD group?" -button1text "Yes" -button2text "No"
                $global:message.Add_ButtonClicked({
                    $buttonArgs  = [SimpleDialogs.Controls.DialogButtonClickedEventArgs]$args[1]	
                    $buttonValues = $buttonArgs.Button
                    If($buttonValues -eq "FirstButton")
                        {
                            Start-SelectedRemediation -remediation $WPFListViewRemediation.SelectedItem
                        }				
                })
            }
        }
    }
}

function Set-UiAction{
    # Search
    Add-XamlEvent -object $WPFTextboxSearchBoxDevice -event "Add_TextChanged" -scriptBlock {
        Search-Device -searchString $($WPFTextboxSearchBoxDevice.Text)
    }

    # Device 
    Add-XamlEvent -object $WPFListViewAllDevices -event "Add_MouseDoubleClick" -scriptBlock {
        $global:SelectedDevice = $WPFListViewAllDevices.SelectedItem
        Open-DeviceView -deviceId $global:SelectedDevice.Id | Out-Null
    }
   
}

function Hide-All {
    $WPFTextboxSearchBoxDevice.Text = ""
    $WPFGridAbout.Visibility="Collapsed"
    $WPFGridDeviceFinder.Visibility="Collapsed"
    $WPFGridDeviceView.Visibility="Collapsed"
}

function Open-DeviceView {
    param (
        [Parameter(Mandatory = $true)]
        [String]$deviceId
    )
    Hide-All
    
    # Get device Info
    $device = Get-DeviceData -deviceId $deviceId

    # Remediations
    if($device.DeviceType -eq 'windowsRT'){
        $WPFTABRemediation.Visibility="Visible"
        Add-RemediationsToGrid -deviceId $deviceId
    }else{
        $WPFTABRemediation.Visibility="Collapsed"
    }
    

    ## Labbels to UI
    $WPFLableDeviceName.Content = $device.DeviceName
    $WPFLableSerialNr.Content = $device.SerialNr

    # Ids
    $WPFLabelIntuneDeviceId.Content = $device.Id
    $WPFLabelAzureAdDeviceId.Content = $device.AzureAdId
    $WPFLabelAdDirectoryId.Content = $device.AzureAdDirectoryId
    $WPFLabelDeviceHashId.Content = $device.DeviceHashId




    $WPFGridDeviceView.Visibility="Visible"
}
########################################################################################
###################################### Navigation ######################################
########################################################################################

function Set-UserInterface {
    #Load images for UI
    $iconHome = "iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAABmJLR0QA/wD/AP+gvaeTAAABPElEQVRIiWNgGFHAYerzYoepz4tJ0cNIlKr//xmdpr5o/8/wvxwqMsn+jWRhQwPjP4otCG24yvZGRHA+AwNDFJrU2v/cP2MOJCr+INsCt+4X3L85/61hYGDwwK7i/z6OfxyB2/OEP5FsgfOEl+L/WP5uZWBgMCbgwsvM//947M6Ve0a0BXaTXyiyMP3b+f8/gyo+w5HAfSaGfx57c2RuoUswoQs4TntmzMz47zgJhjMwMDAo/mNgOuYw6YUFXgucJr9wYvjHsI+BgUGcBMNhQJiR6d8ep8nPPbFa4DD1WfR/xn/bGRgY+MgwHAa4/zP+3+Q45WkSigUOk5/lM/5nWMTAwMBGgeEwwMLAwDjHYcrTcgYGLJHsOOXZf0pM358jhWImRiRTG9DcAhZiFaJ7ndigHPpBNGrBKKAcAAB1CWAtKzJosQAAAABJRU5ErkJggg=="
    $iconButtonLogIn = "iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAABmJLR0QA/wD/AP+gvaeTAAAA1klEQVRIie2TsQrCMBCGc126dhcXX6Iv5OjkY1R9DPUFHHwQQdzV0lnBST+XBGs90xIpVPGHQHL5Lj+5S4z5q3MCYmAGHO2YAnEopxlMeVUWymkGuZKYh3KR5qHErqGcZjBXYosPuGfZ5k2Agx2Zp8m13A8JSIAhsAZ2wBm42NeyBCIPdwK2NjYGkurhKVAoz85p1JBzKoC0bLCpSRjUcCugp1VGbOLNzd8oEhE8XF9E9j4D7dM8IBEvV913a2P0j9ZduYaUY766Nz7Ut//9JWr9Bq0b3AFSVbeeEsxapQAAAABJRU5ErkJggg=="
    $iconSearch = "iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAMAAADXqc3KAAAABGdBTUEAALGPC/xhBQAAACBjSFJNAAB6JgAAgIQAAPoAAACA6AAAdTAAAOpgAAA6mAAAF3CculE8AAAAgVBMVEUAAAAknvMnmfUomfUomfUnmfUpmvUjl/MomPYomfUomfYnmPYpmvYomfUpmvUol/Muov8omvcnmfUomfUmmfIomfUpmPQnmfQomPUomfUnmfMomfUnnesrlf8omfUkku0nm/MomfUomPUnmfUomvQpmfUomfUnmvYomfUomfX///+Vwm5wAAAAKXRSTlMAFYLO9M+DFlLx8lRR/bBACz+v/hTwd3WBskHQDQzzDkKAs+95fc2IfxLEHQcAAAABYktHRCpTvtSeAAAAB3RJTUUH5gYUDicDFaCpggAAAJ5JREFUKM+tkNkOgjAQRVs2obILtaDsgt7//0GJpHFq9Enm6eTc5GZmGPtnuGU7jusdPr0f4DXiaPowQpykaZbjZCRFCbnRGYK2KVQac3gksFFrzHAhgcBVY4PWCLp3IIyqXmMClwQDRo0xLHr2hNtGEgGnh8zA2DdNXSHyjSbM0/aSMjQ9GFeL0y6qIP6+evnl33t59vjh15UGtsc8AfKLD4mzmPrPAAAAJXRFWHRkYXRlOmNyZWF0ZQAyMDIyLTA2LTIwVDE0OjM5OjAzKzAwOjAwYoXoEAAAACV0RVh0ZGF0ZTptb2RpZnkAMjAyMi0wNi0yMFQxNDozOTowMyswMDowMBPYUKwAAAAASUVORK5CYII="   
    $iconRefresh = "iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAABmJLR0QA/wD/AP+gvaeTAAACVUlEQVRIid2VQWsTQRTHf283qUkTtXhrUSlSSNLc2i8gqBVPBg89etBKlIpQaAW9NLfWVi8epFv04EkICI1Xix9A7K2lKUUQlfaitEqS1TTZ52G3sk3SJS160P9peDPz/82+nXkP/nVJ0GQ6rx21bTsjOBnUGAA9CSjIZ5QlhYW4RAtLWdnx70ta5VwxG8sFApJzlSuIzgJngs+o66oysXYzVvDMJ4FcMRuT1oCcGqlue1rRCS+yrCJPTeqLoUj8A0DtR6lX1byg6AiQBhRlGuEnkAPYF5CyKjOeeVWEsdWNzjly4rQ8fF7NxJY9KuhDIOyfagnw0vISqKrhXFq7cfRNcHq8ffPl5yhXWwGM3UA6rx1ezhFhrG1zqzzZaO7Xb0Bt287g/tDl1a5Oq21zL+dtLC69SFplTViVO21taFOGbzwAENL64l8CSA8A9fjHPwkINQZqkS+BrztIfY+/HgsdiXwDvhezseOw5wt0AyC0Ezl1WEA43HHaHcnmbswHMN4BOGIOHRaghlwEUHjbBFCh4E7qCHk1D+yeVxPkmmvGqyZAqCu6IPAeSCe37FsH9U9s27eBftD1uEQLTYCVYaki4hU4fdQ/VzrXrnlqvnReVGcBVZFxf/luujEJq/JA0LtAFZXx4onoE4al3sr4bE5Dmz32qGceBpkuZjvv+de0LNeJbnvKgwCsCPIMp/7acNxy7RilXhVzCNHrblpQFZlZ24jeb6y8+975lFXOKMwCffutcbW34TQq8FENWhouqX1ZIIMw6LVMBD6BLDlKoVXL/L/0C7qI6rgG7zcJAAAAAElFTkSuQmCC"
    $iconPaging = "iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAABmJLR0QA/wD/AP+gvaeTAAAB3UlEQVRIidWVMWtTYRSGn/MlanJvM7fYChXE3jgouLk5OTTaQcHVQUxT/AN1sVpE9BfopX9BESXVwdWtOLjYNIsZQm0Hl9qbREzOcWiE9N5EmljBvtPh/V7OA985Hx8cdUncyIdRwSAEJofsVVehWC3673pNF08ZPB+hOcCUGGHcTACAqRGaAyBw6iCAQ9U/Bxx9JdY0CCP7m4aVeX9fz/96yAq8wZhrkzrT/uFlBE7GQ+kRm9dVuF4t+msx/+thAGqptl2q3B3bCp41p3F6D5gFxoFtYBV1TyoL2RoMP+SO4i5X57MfgnD3CrgXYLlkTL6L6Y310tj7BOAgmllpnha1T2A5jLI6ljMZ73Or1TjnjCWgAOxIyp0faQaiugjkMMqVkn+t52gNuBqEURkooLqYAPzpiizN5MZtf5O9O8fgYb+cqiw7ZwUzZoda007kfeuW4wAnPG+9X06OR7/9iaEAx7zWRLfcBvjZbMwEYfQgAVDvbLfc6geoDwKo6oVu+RrA4CWwtC9kJij3AUR4mwCoUBwEEeMWQKptj4AWMN17ng+ji/mVxitgDtixjnuaGHL3T038TL3qpKUEZOK+wUf2VmQXsZuVhWxtpHcwSEEYbRqs4tzjjTvZLwC/AJiinuCuqDEqAAAAAElFTkSuQmCC"  
    $iconCount = "iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAABmJLR0QA/wD/AP+gvaeTAAAAN0lEQVRIiWNgGAUDDRjhrIor/xkYGBgYOnQwxcgBUHOYyDZgxIDROBgFlIPRVDTwYDQORgHlAADHmRgNDUab0wAAAABJRU5ErkJggg=="
    $iconAbout = "iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAABmJLR0QA/wD/AP+gvaeTAAABZklEQVRIidWVPU7DQBCFn4OSAhEkqCkRByA0cAMoiKMoSsEZOAcEcQQOkdQcgZ86/KTB9EiRaCDio/CEWM6uvQlVnrSytfP2Pc/s7lhadURFQaAmqSWpKWlf0o6F3iU9SupL6kdR9LWwM9AGRpTjFWgtIrwGXAcI53EFVEIMXOJvllHdRgwMHbxeSFlc4tsO7pbF8oh94jXcNW9b/ARIbBzbXMfBfyE9HHMGXQcZoG7xJJuVzW161nSmutlNaXoqNwbQ7IhmseFZ86eVNWh4yHlMJJ3be9fDOZibAcaedPM4M/4h8OnhjJc1uDHuLvBRwHMaPAUY7Bn3toQ3nOpm9+A+oP4jex6V8O5cBoMAgwmApPUS3rwWUCW9JP/FCNdFM5NW0coMz4cf4LQwN9KuuKzBRUnpJKAC9Ioy8Xz5JSHtOmMUE7Ynz4CvzZT+MquSYqW9paFZP0okPSg9LYMoir6Dv3zl8AsKfI8ggolmqwAAAABJRU5ErkJggg=="

    # About
    $iconLinkedIn = "iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAABmJLR0QA/wD/AP+gvaeTAAABJ0lEQVRIie2Sr07DUBSHv9N1YmuxGCAMFG5BIJBYeAhCSOpm2wUMju0FyOawPMEegQSFJYHQsTkUCd34k/UgCKQ0KdDugoHP3T/n9+Wee+CfL5DkYrEVbQl0EeaKhCkMUbx+0+m97VkpXado+Gs58yJ0k3tW+kLR8AQLmYIUV4juCBxNY8sUiGon9N3j63G1ATwXFdhZB2pZu0ut0Y1KtA5SNi5AdUWFk9Sg5SazRSrsh4EjYeC8G+xJPBsGjqiySRxvMK5WEF0Fucgt+Ix+0+k9Pbpn4YE8hL57LqhvVLB8GK2VK6O7Wvt+G6A0iU+NCrREXcBGqQNc7s3cGhUQf//niwly8OOCD0+ttSM1EZoc7d9tkcLQQOYgU4DiTSkZIOpNUf8XeQFjeFM4aqoyewAAAABJRU5ErkJggg=="
    $iconTwitter = "iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAABmJLR0QA/wD/AP+gvaeTAAACA0lEQVRIie2SP2gTcRTHP+9y1+Qutf4dxCEJHXTUooOtWLqJILqIgrMgAXFqbMUlXUzqqCCosyIu4uBSFBHxz6A4ZQnFFrVasQ62uYsxXp5L06bJ5Uy66NDv+H3vfb7v9/jBhv61pNuBXVl1LNsbFzgDJICPCnd8y8ltXsR3Y95RhH2zY/GJloBk3r1mOU5m+oJU2sF7bO8JcDCg/B7YDiyYyMj0mPMJwFgpqwpC+nfZu79n8tumoADL9sbbwAH6gajC06rqibq5GiCiAovA8QrOu8RV71AzYfksYYqBRHdsdW41zKwqOeleFzjfYL0CvR2pmc8r0eicWfWWgEhIgM5edCKIaN0wG6u9ZeeSa7t7QQ4vW4Mgg77hY1a9vywPIKVGODSeCHBjXqYGE8DLDmgBqn1pdtYEqCH9BvIYGFpfAG9DA3o9Oy3wYp1wFB6FBhSyUpopO8MKZ4HXXfLnq+X4g2bTbDZStncPOADs7IYuIlc+Z6XlJxjNRtX300ARsDumK1MzKftGYHC7mWTOHRBDToNmghZpUKEn4o8UR/sWgoprTrT/plrz35f6TMvcbfh6TNFzoXBlyqByqji67Ue7lpUXpPKlI4jkgIGQbev6IKqXZ37G75KVWlhjy4mSeW9IqJ0UQ4ZVSQBbFL6KMicGb1B96JTjzwpZ+dXBIhv6D/QH8mKgEDaLDDsAAAAASUVORK5CYII="
    $iconWordpress = "iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAABmJLR0QA/wD/AP+gvaeTAAAD8ElEQVRIid2VX4iUVRjGf+/5Znfn+2azxT/4J9dZKQpUSDKKErUugoLIyXDcQiMCk4T+XLRuRhcDEbVtGHQRtOJVRbUG6yaBN1uURX/MyEgrMXe2VSMoKXd3vtnd+c7Txcza6mxSl3Uun/Oe53nf5z3nPfBfX3apzeUFNZbScU7mc+CuAy2uHTsF/iuT2xeVw31HCzbxrwWyXaUNhrqBH83oRcnBkrvsFEA4OdJqLljjIW/GUjnrGOqI+v6ZQEEuG8bPG369KdiapCq/usS2gt0CtAENiCHBQCrwPYlSc1CyG3N9xVK4k4L56XSuLvMq+Y0Y62TJ3S5x34I9DqwEWoAMxjIzHkm8O2LyeVVsHfI3tUXxcxfzXSBQtcWvD5w2gnujRnypPjlJw5OT0R+VhiQnaUNb11huRouWF9Q4FpaOmdyDiSUNzuweZOdA90ocx9nXJs3CSGr4JiCbCqPwxKM2Xk1w5FZwPXNbomWHt9nkBRWU0nEOOBmV05/91Nk8UNyR2Y40D5hvxgqkuNiZ2VbckdkuNAeYD1hSHlt3PlufGnTY0Nnf4/V1Fsl8zozeUljqvOplNQGYYxBoAhaYeGzxLoW16O+BEECyFygoVWXzD2HqBXJ1AsAqlByUaJ8sx3dWeZK908yclarEdwF47E0gqe1cm02XblteUDNwhyrJR4LrZxBwCxsZP4NZq0n3Awx2zvoB+OZ8iDQOMNyZOYMYOI8Hlo7T5ZVAW1MwfhpYNFMFUywp4ParXzw3F0DQWythhDg6MGWTodemTjR4DsmUq+e6QMD/PEHTIsyGgMbJJNUOECTB3ppF+2kqLwgm4ocBSkGmTzCKOHZiR3haaCNQLJNeDJypFzD3JQrWmvR+NXNtATj5VPo4cARpLy7ZZFbFf+mwMbA+zPYv6Y5vBpYYNmBya2UcqhMwT7+HPFIP4IEblnaduwbAzPYQRwfA2oGVV3aPrABw5l/3xn4nnwe8J9mDs7wT/XUCUTncVx1cQQvQU0WDLQCDbeErFo5kqY4LEh9sruKZgXmXh1+AbZTZLjwLkW+d3RLWCxwt2IScdaBkdwLPgH0g2ExBjrwlImj/q1+6bwr/7ezoauCIl14y53oMe2LqFV/UZBjqiPow1xegtxK02eC9pVF5ddVDmyZAazYcrb5gF5StogccvA30DnZm3p3OWXdNi6VwJ+Y+dfChx78TldKfZ58dW4gwIAZKwHdOdgWAfBIpZZ+Y2cfFOHr6Yr6/nZRtXWM5QbfDhjD1evmDzXHzMMBI8+gSV3FrcJZHvhVZR/HJTP9MPJf8Mle9qoba4MrJWCVVv0yDYZkddqJ/dkvYP93z/9/6E+aHsqs7a3d1AAAAAElFTkSuQmCC"
    $iconBlog = "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"

    # Device
    $iconDevices = "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"
    $iconDevicesSync = "iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAABmJLR0QA/wD/AP+gvaeTAAACL0lEQVRIie2UTUhUYRSGn/ON4nVuKpO6suD6Uy3ctI+kjRBUZBBCWxcSUVvHIvC28Ge2CRFE0C6QWbiIaBEG/UDLWgSFaGPixhghde6M6P1OCzWcaWbuGC19l4fzvc933vudC0eKkEQ1dKY2+y0yKMh50BMgFtVlFT6Afb6UbHrzT4CuicJpG9t5AtJXzUCV1zETu7U44swDeKmcn0m6flVA51S+T8XOAglgVYRpRV/kxZ1valiLbeecbgzXBG4C7cCasVy0hkvAWCbpSkXA7s3Dj0BCIe0QDH1Ltm+Uu0jHxHprfV3sKcpVYAtoADgIqCs9tBdLQiG9NBIfRFytFM/KveYsvl73GoNPQG+5HlMUTWqzfy/zVYdgCJGK5vvyGoP7lcz/AlhkEECE6UqxFJmncj4wVq2n6Bt4qeAr6BlRPft99NjnKEAtKppA0Q6AeMFd+B/mUMOi1aqeh9nmnbzzC2U9M+q27NdNtUOH0XbB6QFAWDlYL3qmXipX7tX4maT7IAogypU9wNuD9agJajLvmlprUbgNoKGdqRXwJZOPj0eZ46ux0vBMoA2RuaW7TXO1ALaAXi8epDsm1lur3dxzgjQwAGRDzHBpT8ke5BTwjeWlNbwCjgM/FR4jzMbs1kK9hLYg8VMCl1W5I9AGZI2agcXRxvdRgD+/2u7JQk9owkdAf6UJdh1kLsQML484ZXcncg+8yY0LGHMDOIdyUgUjyg8M7zS0M6WZH+nQ+g3+T8fG5ZGFPgAAAABJRU5ErkJggg=="
    $iconDevicesRestart = "iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAABmJLR0QA/wD/AP+gvaeTAAAC30lEQVRIidWVv29TVxTHP+fe51fZQ5FYqgaKShSk2O4PiUSUPwAxpKAEUBaWIIGQWuhCgxOY3hg73ZAoRHRLp6pgFpYKIpghAoFtJH60lVC7shCbh989Hd4zMXlx4o45473n+/2cc3R/wFYP2XA3qPm2JUdwjIuwV2FnInqlyjKi1ShLlaAY/m+AnW0cQ10FZHCTIl+gUooq+ev9ASbVervrZRX5EUCVJyJ8ARCVCwJgZ+q6dk+Qn9rZ4RkCcd12Zq1/l3lL4XtXyX/Vq3SXy3+typk4V6e9lcbc2pwPAHa2caxjLmrGXLnwM0E90wsAdc9VCpdF9FvgrQrnbak+sT4gqPnxzEHhXLsyvETp6YBtyr1e9rYpd7lY/7Q9V7yjyjkAhHmCmp8C2JYcARlU5JHL5q/yw7OPrLgbwDe9O2C/jbhOUPNdLn9F4TEwZFuMpztwyaLqAoE4kwtPAPs2MF+FNM0UgThUFhLbNECEEQBn7R0AUZnqwzwOdVOx1iVaHU0BFAYAaOX+jokM9w0Qycfaj/9MvHZ0trxUcuZNZy11ejrnf52INdtaGZoAvL8LqyOCf2KX6LNkqdZf+YDGuX74blfi9W8KoMoDABPJwVijv/bvzyJAu6MVuZ8CIFpNWjnFpFq34i8oPOzDfNnl9BqTag16EgDnqilAlKUKvBAomt1Pv+PSnrfOs4c2gigsOzWHCYqhGWycVSgAz6PXzZvv6+4W2FLjKKK/A6GojrUrxdsENd+smNOCHkf4MnF+rLDocnqNoBh6s/UDqtwCMqATUbm4PgDAm2nMKzoNhIpOu5eFy/wm0botBEueaX5yRmAeyAhU2uXCTHdK+rkO1HgrjTkVzidjqCH84hn+CH39C8AP5fN2JAcNejIZCwKVdjZ/Ye1z3fvDKdUnEOaBoV45STwHne4eS18AAE7fz9jt2Qkw46JuRJHky9RXKuYBzlWj182bLIy+26SILRz/AZMPK3s3pwpwAAAAAElFTkSuQmCC"
    $iconDevicesShutdown = "iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAABmJLR0QA/wD/AP+gvaeTAAAC30lEQVRIidWVv29TVxTHP+fe51fZQ5FYqgaKShSk2O4PiUSUPwAxpKAEUBaWIIGQWuhCgxOY3hg73ZAoRHRLp6pgFpYKIpghAoFtJH60lVC7shCbh989Hd4zMXlx4o45473n+/2cc3R/wFYP2XA3qPm2JUdwjIuwV2FnInqlyjKi1ShLlaAY/m+AnW0cQ10FZHCTIl+gUooq+ev9ASbVervrZRX5EUCVJyJ8ARCVCwJgZ+q6dk+Qn9rZ4RkCcd12Zq1/l3lL4XtXyX/Vq3SXy3+typk4V6e9lcbc2pwPAHa2caxjLmrGXLnwM0E90wsAdc9VCpdF9FvgrQrnbak+sT4gqPnxzEHhXLsyvETp6YBtyr1e9rYpd7lY/7Q9V7yjyjkAhHmCmp8C2JYcARlU5JHL5q/yw7OPrLgbwDe9O2C/jbhOUPNdLn9F4TEwZFuMpztwyaLqAoE4kwtPAPs2MF+FNM0UgThUFhLbNECEEQBn7R0AUZnqwzwOdVOx1iVaHU0BFAYAaOX+jokM9w0Qycfaj/9MvHZ0trxUcuZNZy11ejrnf52INdtaGZoAvL8LqyOCf2KX6LNkqdZf+YDGuX74blfi9W8KoMoDABPJwVijv/bvzyJAu6MVuZ8CIFpNWjnFpFq34i8oPOzDfNnl9BqTag16EgDnqilAlKUKvBAomt1Pv+PSnrfOs4c2gigsOzWHCYqhGWycVSgAz6PXzZvv6+4W2FLjKKK/A6GojrUrxdsENd+smNOCHkf4MnF+rLDocnqNoBh6s/UDqtwCMqATUbm4PgDAm2nMKzoNhIpOu5eFy/wm0botBEueaX5yRmAeyAhU2uXCTHdK+rkO1HgrjTkVzidjqCH84hn+CH39C8AP5fN2JAcNejIZCwKVdjZ/Ye1z3fvDKdUnEOaBoV45STwHne4eS18AAE7fz9jt2Qkw46JuRJHky9RXKuYBzlWj182bLIy+26SILRz/AZMPK3s3pwpwAAAAAElFTkSuQmCC"
    
    # Remediation
    $iconExecute = "iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAABmJLR0QA/wD/AP+gvaeTAAABAklEQVRIie2PsU4CURBF7+w8gWhhYW1J4obSztpf4DPE2Pg2MYbt1gQLDAWNpRUfQENLLEwIhS4vgdBTmxBC2OdYmO2MvgW2gtPemXtmgD27DetRr6DjyiYd3j/5pQUNVWCeoKfHeQgA4EBEaozl1NOja4TispNJkHJCQJMX5k1pc5GHIOVcIH3WpoO799M8BABAgFQ5YaOCOMTVpLhtQcqRCNX5cPXBQVzNQwDg5x1Yb/FbpjbsnhPJYzIvRGiVl9sUCAgv1sotGpXZX4PrCAYEqiUP/qvLcBbBDER1Wzp7RkhfrksughURtZOSukdY/sxwkINA0LVMN4j8cdbiPTvEN7r9SyjbfJ9xAAAAAElFTkSuQmCC"

    # Add image to UI
    $WPFImgHome.source = Get-DecodeBase64Image -ImageBase64 $iconHome
    $WPFImgButtonLogIn.source = Get-DecodeBase64Image -ImageBase64 $iconButtonLogIn
    $WPFImgSearchBoxDevice.source = Get-DecodeBase64Image -ImageBase64 $iconSearch
    $WPFImgRefresh.source = Get-DecodeBase64Image -ImageBase64 $iconRefresh
    $WPFImgMaxDevices.source = Get-DecodeBase64Image -ImageBase64 $iconPaging
    $WPFImgDeviceCount.source = Get-DecodeBase64Image -ImageBase64 $iconCount
    $WPFImgButtonAbout.source = Get-DecodeBase64Image -ImageBase64 $iconAbout

    #About
    $WPFImgTwitter.source = Get-DecodeBase64Image -ImageBase64 $iconTwitter
    $WPFImgWordpress.source = Get-DecodeBase64Image -ImageBase64 $iconWordpress
    $WPFImgLinkedIn.source = Get-DecodeBase64Image -ImageBase64 $iconLinkedIn
    $WPFImgBlog.source = Get-DecodeBase64Image -ImageBase64 $iconBlog
    
    # Device
    $WPFImgDevice.source = Get-DecodeBase64Image -ImageBase64 $iconDevices
    $WPFImgSyncDevice.source = Get-DecodeBase64Image -ImageBase64 $iconDevicesSync
    $WPFImgRestartDevice.source = Get-DecodeBase64Image -ImageBase64 $iconDevicesRestart
    $WPFImgShutdownDevice.source = Get-DecodeBase64Image -ImageBase64 $iconDevicesShutdown

    # Device Remediation
    $WPFImgRefreshRemediations.source = Get-DecodeBase64Image -ImageBase64 $iconRefresh
    $WPFImgRunRemediations.source = Get-DecodeBase64Image -ImageBase64 $iconExecute

    # Fill combo box    
    $valueGroupCount = "10", "100", "500", "1000", "5000", "10000", "All"
    foreach ($value in $valueGroupCount) { $WPFComboboxDevicesCount.items.Add($value) | Out-Null }
    $WPFComboboxDevicesCount.SelectedIndex = 2

    # Reset lables
    $WPFLableUPN.Content = ""
    $WPFLableTenant.Content = ""
    $WPFImgButtonLogIn.Width="25"
    $WPFImgButtonLogIn.Height="25"
}