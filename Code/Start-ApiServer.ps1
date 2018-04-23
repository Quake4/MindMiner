<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

# https://learn-powershell.net/2013/04/19/sharing-variables-and-live-objects-between-powershell-runspaces/

. .\Code\Config.ps1

function Start-ApiServer {
	$global:API.Running = $true
	$global:API.Port = [Config]::ApiPort
	$global:ApiRunSpace = [runspacefactory]::CreateRunspace()
	$global:ApiRunSpace.Open()
	$global:ApiRunSpace.SessionStateProxy.SetVariable("API", $global:API)
	$global:ApiPowerShell = [powershell]::Create()
	$global:ApiPowerShell.Runspace = $ApiRunSpace
	$global:ApiPowerShell.AddScript({
		try {
			$listner = [Net.HttpListener]::new()
			$listner.Prefixes.Add("http://localhost:$($API.Port)/")
			$listner.Start()
			while ($API.Running -and $listner.IsListening) {
				$context = $listner.GetContext()
				$request = $context.Request

				$contenttype = "application/json"
				$statuscode = 200
				$content = $null

				$local = if ($context.Request.Url.LocalPath) { $context.Request.Url.LocalPath.ToLower() } else { [string]::Empty }

				switch ($local) {
					"/pools" {
						$content = $API.Pools | ConvertTo-Json
					}
					default {
						$statuscode = 404
						$contenttype = "text/html"
						$content = "Unknown request: $($context.Request.Url)"
					}
				}

				if (!$content) {
					$statuscode = 449
				}

				# send the response
				$response = $context.Response
				$response.StatusCode = $statuscode
				if ($statuscode -ne 449) {
					$response.Headers.Add("Content-Type", $ContentType)
					$responseBuffer = [System.Text.Encoding]::UTF8.GetBytes($content)
					$response.ContentLength64 = $responseBuffer.Length
					$response.OutputStream.Write($responseBuffer, 0, $responseBuffer.Length)
				}
				$response.Close()
			}
			$listner.Stop()
		}
		catch {
			"$([datetime]::Now): $_" | Out-File "Api.exception.txt" -Append -Force
		}
		finally {
			$listner.Stop()
			$listner.Close()
			$listner.Dispose()
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