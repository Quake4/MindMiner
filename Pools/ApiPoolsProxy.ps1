<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Include.ps1

if ($Config.ApiPoolsProxy -as [eApiPoolsProxy] -ne [eApiPoolsProxy]::Slave) { return $null }

$PoolInfo = [PoolInfo]::new()
$PoolInfo.Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $PoolInfo.Name + [BaseConfig]::Filename), @{
	 ProxyList = $null
})

if (!$Cfg) { return $null }
$PoolInfo.Enabled = $Cfg.Enabled
if (!$Cfg.Enabled) { return $null }

$currentfilename = [IO.Path]::Combine($PSScriptRoot, $PoolInfo.Name + ".current.txt")
$Current = [BaseConfig]::ReadOrCreate($currentfilename, @{
	Proxy = $null
})

$proxylist = [Collections.Generic.List[string]]::new()
if (![string]::IsNullOrWhiteSpace($Current.Proxy)) {
	$proxylist.Add($Current.Proxy)
}
$Cfg.ProxyList | ForEach-Object {
	if (![string]::IsNullOrWhiteSpace($_)) {
		$proxylist.Add($_)
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

			$RequestPools | ForEach-Object {
				$PoolInfo.$PoolInfo.Algorithms.Add($_ -as [PoolAlgorithmInfo])
			}
			
			if ($Current.Proxy -ne $_) {
				$Current.Proxy = $_
				$Current.Save($currentfilename)
			}
		}
	}
}

$PoolInfo