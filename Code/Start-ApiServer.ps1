<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

# https://learn-powershell.net/2013/04/19/sharing-variables-and-live-objects-between-powershell-runspaces/

function Start-ApiServer {
	$global:API.Running = $true
	$global:ApiRunSpace = [runspacefactory]::CreateRunspace()
	$global:ApiRunSpace.Open()
	$global:ApiRunSpace.SessionStateProxy.SetVariable("API", $global:API)
	$global:ApiPowerShell = [powershell]::Create()
	$global:ApiPowerShell.Runspace = $ApiRunSpace
	$global:ApiPowerShell.AddScript({
		try {
			while ($API.Running) {
				$result = "$([datetime]::Now)" + [Environment]::NewLine
				$API.Keys | ForEach-Object {
					$result += "$_`: $($API.$_)" + [Environment]::NewLine
				}
				$result | Out-File "Api.txt" -Force
				Start-Sleep -Seconds 1
			}
		}
		catch {
			"$([datetime]::Now): $($_)$([environment]::NewLine)" | Out-File "Api.exception.txt" -Append -Force
		}
	}) | Out-Null
	$global:ApiHandle = $ApiPowerShell.BeginInvoke()
}

function Stop-ApiServer {
	$global:API.Running = $false
	$global:ApiPowerShell.EndInvoke($ApiHandle)
	$global:ApiRunSpace.Close()
	$global:ApiPowerShell.Dispose()	
}