<#
MindMiner  Copyright (C) 2017-2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

[hashtable] $WebSessions = [hashtable]@{}

function GetUrl {
	param(
		[Parameter(Mandatory = $true)]
		[String]$url,
		[Parameter(Mandatory = $false)]
		[String]$filename
	)

	if ([Net.ServicePointManager]::SecurityProtocol -notmatch [Net.SecurityProtocolType]::Tls12) {
		[Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12
	}
		
	$result = $null
	$timeout = [int]($Config.LoopTimeout / 4)
	$agent = "MindMiner/$([Config]::Version)"
	$hst = [uri]::new($url).Host
	[Microsoft.PowerShell.Commands.WebRequestSession] $session = $WebSessions.$hst

	1..5 | ForEach-Object {
		if (!$result) {
			try {
				if ($filename) {
					if (!$session) {
						$req = Invoke-WebRequest $url -OutFile $filename -PassThru -TimeoutSec $timeout -UserAgent $agent -SessionVariable session
					}
					else {
						$req = Invoke-WebRequest $url -OutFile $filename -PassThru -TimeoutSec $timeout -UserAgent $agent -WebSession $session
					}
					$result = $true
				}
				else {
					if (!$session) {
						$req = Invoke-WebRequest $url -TimeoutSec $timeout -UserAgent $agent -SessionVariable session
					}
					else {
						$req = Invoke-WebRequest $url -TimeoutSec $timeout -UserAgent $agent -WebSession $session
					}
					$result = $req | ConvertFrom-Json
				}
			}
			catch {
				if ($req -is [IDisposable]) {
					$req.Dispose()
					$req = $null
				}
				if ($_.Exception -is [Net.WebException] -and ($_.Exception.Response.StatusCode -eq 503 -or $_.Exception.Response.StatusCode -eq 449)) {
					Start-Sleep -Seconds 15
				}
				else {
					try {
						if ($filename) {
							if (!$session) {
								$req = Invoke-WebRequest $url -OutFile $filename -PassThru -TimeoutSec $timeout -UseBasicParsing -UserAgent $agent -SessionVariable session
							}
							else {
								$req = Invoke-WebRequest $url -OutFile $filename -PassThru -TimeoutSec $timeout -UseBasicParsing -UserAgent $agent -WebSession $session
							}
							$result = $true
						}
						else {
							if (!$session) {
								$req = Invoke-WebRequest $url -TimeoutSec $timeout -UseBasicParsing -UserAgent $agent -SessionVariable session
							}
							else {
								$req = Invoke-WebRequest $url -TimeoutSec $timeout -UseBasicParsing -UserAgent $agent -WebSession $session
							}
							$result = $req | ConvertFrom-Json
						}
					}
					catch {
						$result = $null
					}
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
		[String]$url
	)

	GetUrl $url
}

function Get-UrlAsFile {
	param(
		[Parameter(Mandatory = $true)]
		[String]$url,
		[Parameter(Mandatory = $true)]
		[String]$filename
	)

	GetUrl $url $filename
}