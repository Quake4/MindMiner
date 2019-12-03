<#
MindMiner  Copyright (C) 2017-2019  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

[hashtable] $WebSessions = [hashtable]@{}

function Get-Rest([Parameter(Mandatory = $true)][string] $Url) {
	if ([Net.ServicePointManager]::SecurityProtocol -notmatch [Net.SecurityProtocolType]::Tls12) {
		[Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12
	}

	$result = $null
	$timeout = [int]($Config.LoopTimeout / 4)
	$agent = "MindMiner/$([Config]::Version)"
	$hst = [uri]::new($Url).Host
	[Microsoft.PowerShell.Commands.WebRequestSession] $session = $WebSessions.$hst

	1..5 | ForEach-Object {
		if (!$result) {
			try {
				if (!$session) {
					$req = Invoke-RestMethod -Uri $Url -TimeoutSec $timeout -UseBasicParsing -UserAgent $agent -SessionVariable session
				}
				else {
					$req = Invoke-RestMethod -Uri $Url -TimeoutSec $timeout -UseBasicParsing -UserAgent $agent -WebSession $session
				}
				if (!($req -is [PSCustomObject]) -and !($req -is [array]) -and [string]::IsNullOrWhiteSpace([string]$req)) {
					Start-Sleep -Seconds 15
				}
				else {
					$result = $req
				}
			}
			catch {
				if ($_.Exception -is [Net.WebException] -and ($_.Exception.Response.StatusCode -eq 503 -or $_.Exception.Response.StatusCode -eq 449)) {
					Start-Sleep -Seconds 15
				}
			}
			finally {
				if ($req -is [IDisposable]) {
					$req.Dispose()
					$req = $null
				}
			}
		}
	}

	if ($result -and !$WebSessions.$hst -and $session -and $session.Cookies.Count -gt 0) {
		$WebSessions.Add($hst, $session)
	}

	$result
}

function Get-UrlAsJson {
	param(
		[Parameter(Mandatory = $true)]
		[String]$Url
	)

	if ([Net.ServicePointManager]::SecurityProtocol -notmatch [Net.SecurityProtocolType]::Tls12) {
		[Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12
	}

	$result = $null
	$timeout = [int]($Config.LoopTimeout / 4)
	$agent = "MindMiner/$([Config]::Version)"
	$hst = [uri]::new($Url).Host
	[Microsoft.PowerShell.Commands.WebRequestSession] $session = $WebSessions.$hst

	1..5 | ForEach-Object {
		if (!$result) {
			try {
				if (!$session) {
					$req = Invoke-WebRequest $Url -Proxy $Proxy -TimeoutSec $timeout -UseBasicParsing -UserAgent $agent -SessionVariable session
				}
				else {
					$req = Invoke-WebRequest $Url -Proxy $Proxy -TimeoutSec $timeout -UseBasicParsing -UserAgent $agent -WebSession $session
				}
				if ([string]::IsNullOrWhiteSpace([string]$req)) {
					Start-Sleep -Seconds 15
				}
				else {
					$result = $req | ConvertFrom-Json
				}
			}
			catch {
				if ($_.Exception -is [Net.WebException] -and ($_.Exception.Response.StatusCode -eq 503 -or $_.Exception.Response.StatusCode -eq 449)) {
					Start-Sleep -Seconds 15
				}
			}
			finally {
				if ($req -is [IDisposable]) {
					$req.Dispose()
					$req = $null
				}
			}
		}
	}

	if ($result -and !$WebSessions.$hst -and $session -and $session.Cookies.Count -gt 0) {
		$WebSessions.Add($hst, $session)
	}

	$result
}