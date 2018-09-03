<#
MindMiner  Copyright (C) 2017-2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

[hashtable] $WebSessions = [hashtable]@{}

function GetUrl {
	param(
		[Parameter(Mandatory = $true)]
		[String]$Url,
		[Parameter(Mandatory = $false)]
		[String]$Filename,
		[Parameter(Mandatory = $false)]
		[String]$Proxy
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
				if ($Filename) {
					if (!$session) {
						if ([string]::IsNullOrWhiteSpace($Proxy)) {
							$req = Invoke-WebRequest $Url -OutFile $Filename -PassThru -TimeoutSec $timeout -UseBasicParsing -UserAgent $agent -SessionVariable session
						}
						else {
							$req = Invoke-WebRequest $Url -OutFile $Filename -PassThru -Proxy $Proxy -TimeoutSec $timeout -UseBasicParsing -UserAgent $agent -SessionVariable session
						}
					}
					else {
						if ([string]::IsNullOrWhiteSpace($Proxy)) {
							$req = Invoke-WebRequest $Url -OutFile $Filename -PassThru -TimeoutSec $timeout -UseBasicParsing -UserAgent $agent -WebSession $session
						}
						else {
							$req = Invoke-WebRequest $Url -OutFile $Filename -PassThru -Proxy $Proxy -TimeoutSec $timeout -UseBasicParsing -UserAgent $agent -WebSession $session
						}
					}
					$result = $true
				}
				else {
					if (!$session) {
						if ([string]::IsNullOrWhiteSpace($Proxy)) {
							$req = Invoke-WebRequest $Url -TimeoutSec $timeout -UseBasicParsing -UserAgent $agent -SessionVariable session
						}
						else {
							$req = Invoke-WebRequest $Url -Proxy $Proxy -TimeoutSec $timeout -UseBasicParsing -UserAgent $agent -SessionVariable session
						}
					}
					else {
						if ([string]::IsNullOrWhiteSpace($Proxy)) {
							$req = Invoke-WebRequest $Url -TimeoutSec $timeout -UseBasicParsing -UserAgent $agent -WebSession $session
						}
						else {
							$req = Invoke-WebRequest $Url -Proxy $Proxy -TimeoutSec $timeout -UseBasicParsing -UserAgent $agent -WebSession $session
						}
					}
					if ([string]::IsNullOrWhiteSpace([string]$req)) {
						Start-Sleep -Seconds 15
					}
					else {
						$result = $req | ConvertFrom-Json
					}
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
		[String]$Url,
		[Parameter(Mandatory = $false)]
		[String]$Proxy
	)

	GetUrl $Url -Proxy $Proxy
}

function Get-UrlAsFile {
	param(
		[Parameter(Mandatory = $true)]
		[String]$Url,
		[Parameter(Mandatory = $true)]
		[String]$Filename,
		[Parameter(Mandatory = $false)]
		[String]$Proxy
	)

	GetUrl $Url $Filename $Proxy
}