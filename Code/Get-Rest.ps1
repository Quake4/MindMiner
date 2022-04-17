<#
MindMiner  Copyright (C) 2017-2022  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

[hashtable] $WebSessions = [hashtable]@{}

function Get-Rest([Parameter(Mandatory = $true)][string] $Url, [string] $Body) {
	if ([Net.ServicePointManager]::SecurityProtocol -notmatch [Net.SecurityProtocolType]::Tls12) {
		[Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12
	}
	<#
	try
	{
		if ([Net.ServicePointManager]::SecurityProtocol -notmatch [Net.SecurityProtocolType]::Tls13) {
			[Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls13
		}
	}
	catch { }
	#>

	$result = $null
	$timeout = 15 # [int]($Config.LoopTimeout / 4)
	$agent = "MindMiner/$([Config]::Version -replace "v")"
	$hst = [uri]::new($Url).Host
	[Microsoft.PowerShell.Commands.WebRequestSession] $session = $WebSessions.$hst

	1..3 | ForEach-Object {
		if (!$result) {
			try {
				if (!$session) {
					if ([string]::IsNullOrWhiteSpace($Body)) {
						$req = Invoke-RestMethod -Uri $Url -TimeoutSec $timeout -UseBasicParsing -UserAgent $agent -SessionVariable session
					}
					else {
						$req = Invoke-RestMethod -Uri $Url -Method "POST" -Body $Body -TimeoutSec $timeout -UseBasicParsing -UserAgent $agent -SessionVariable session
					}
				}
				else {
					if ([string]::IsNullOrWhiteSpace($Body)) {
						$req = Invoke-RestMethod -Uri $Url -TimeoutSec $timeout -UseBasicParsing -UserAgent $agent -WebSession $session
					}
					else {
						$req = Invoke-RestMethod -Uri $Url -Method "POST" -Body $Body -TimeoutSec $timeout -UseBasicParsing -UserAgent $agent -WebSession $session
					}
				}
				if (!($req -is [PSCustomObject]) -and !($req -is [array]) -and [string]::IsNullOrWhiteSpace([string]$req)) {
					Start-Sleep -Seconds $timeout
				}
				else {
					$result = $req
				}
			}
			catch {
				if ($_.Exception -is [Net.WebException] -and ($_.Exception.Response.StatusCode -eq 503 -or $_.Exception.Response.StatusCode -eq 449)) {
					Start-Sleep -Seconds $timeout
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