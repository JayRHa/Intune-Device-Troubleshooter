# Intune-Device-Troubleshooter
Intune Device Troubleshooter

[Blog Post]()
<p align="left">
  <a href="https://twitter.com/jannik_reinhard">
    <img src="https://img.shields.io/twitter/follow/jannik_reinhard?style=social" target="_blank" />
  </a>
    <a href="https://github.com/JayRHa">
    <img src="https://img.shields.io/github/followers/JayRHa?style=social" target="_blank" />
  </a>
</p>

If you follow my blog, you know that there are two things I really like: helping people with their problems, and automating or simplifying processes. In this blog, I want to introduce you to my new tool, the Intune Device Troubleshooter. This is a PowerShell UI application that will help you to check the status of your devices, as well as support you to trigger remediation scripts to fix issues add-hock on single devices. It also provides you intelligent recommendations what you should check at a single device to determine and possible issue. So let's get started and look at the features of the tool.
![Tool View](https://github.com/JayRHa/Intune-Device-Troubleshooter/blob/main/.images/startpage.png)

## Device Overview

The Intune Device Troubleshooter provides you with a great overview of a lot of data around a single device that you wouldn't be able to get all of them through the MEM interface. The data is prepared and gives you a very clear view of the status of the device. If you double click on the IDs of the devices, it will open up the MEM console or Azure AD directly, where you can make changes as well.
![View](https://github.com/JayRHa/Intune-Device-Troubleshooter/blob/main/.images/overview.png)

## Trigger Action

You can perform actions directly through the tool, such as syncing the device or restarting it.
![View](https://github.com/JayRHa/Intune-Device-Troubleshooter/blob/main/.images/action.png)

## Recommendations

All the data that is accessible for thisdevice is intelligently analysed and suggestions are made to quickly see what might be wrong with the device so that you can check or fix it. This speeds up your troubleshooting process and prevents you from missing anything. If you have any further ideas for checks, please let me know so that I can include them.
![View](https://github.com/JayRHa/Intune-Device-Troubleshooter/blob/main/.images/recommendations.png)

## Remediation Scrips trigger

This is a feature that can really help you with the solving of errors. In the MEM Console, you can only assign remediation scripts to a group but you can't trigger it on an individual device. That's exactly what I did with the Intune Troubleshooter. If you want to run an action on a single device, you can trigger the script and I'll create a group in the background (if it doesn't already exist) with the name "MDM-Remediation-Trigger-{ScriptName}" which you can of course change, and add the device to it. So the remediation action will be performed on the device quite timely.
![View](https://github.com/JayRHa/Intune-Device-Troubleshooter/blob/main/.images/remediation.png)