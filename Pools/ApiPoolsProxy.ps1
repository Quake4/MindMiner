<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Include.ps1

function Get-ApiPoolsUri ([string] $url) {
	$hst = $url
	try {
		$inp = [uri]::new($url)
		$hst = $inp.Host
	}
	catch { }
	[uri]::new("http://$hst`:$([Config]::ApiPort)/pools")
}

$PoolInfo = [PoolInfo]::new()
$PoolInfo.Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $PoolInfo.Name + [BaseConfig]::Filename), @{
	Enabled = $false
	ProxyList = $null
})
if (!$Cfg) { return $null }

$PoolInfo.Enabled = $Cfg.Enabled
[Config]::UseApiProxy = $PoolInfo.Enabled
if (!$Cfg.Enabled) { return $null }

$currentfilename = [IO.Path]::Combine($PSScriptRoot, $PoolInfo.Name + ".current.txt")
$Current = [BaseConfig]::ReadOrCreate($currentfilename, @{
	Proxy = $null
})

$proxylist = [Collections.Generic.List[uri]]::new()
if (![string]::IsNullOrWhiteSpace($Current.Proxy)) {
	$proxylist.Add((Get-ApiPoolsUri $Current.Proxy))
}
$Cfg.ProxyList | ForEach-Object {
	if (![string]::IsNullOrWhiteSpace($_)) {
		$proxylist.Add((Get-ApiPoolsUri $_))
	}
}

$proxylist | ForEach-Object {
	if (!$PoolInfo.HasAnswer) {
		try {
			$RequestPools = Get-UrlAsJson $_
		}
		catch { }
		if ($RequestPools) {
			$PoolInfo.HasAnswer = $true
			$PoolInfo.AnswerTime = [DateTime]::Now
			$PoolInfo.AverageProfit = $_.Host

			$RequestPools | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
				$PoolInfo.Algorithms.Add([PoolAlgorithmInfo]$RequestPools.$_)
			}
			
			if ($Current.Proxy -ne $_.Host) {
				$Current.Proxy = $_.Host
				$Current | ConvertTo-Json | Out-File -FilePath $currentfilename -Force
			}
		}
	}
}

$PoolInfo