<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::CPU) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 60
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptolight" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightheavy" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightv7" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightv8" }
)}

if (!$Cfg.Enabled) { return }

$file = [IO.Path]::Combine($BinLocation, $Name, "config.json")
if ([IO.File]::Exists($file)) {
	[IO.File]::Delete($file)
}

$url = if ([Config]::Is64Bit -eq $true) { "https://github.com/xmrig/xmrig/releases/download/v2.13.0/xmrig-2.13.0-gcc-win64.zip" } else { "https://github.com/xmrig/xmrig/releases/download/v2.13.0/xmrig-2.13.0-gcc-win32.zip" }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				$add = [string]::Empty
				if ($extrargs -notmatch "--variant") {
					$add = "--variant 1"
					if ($_.Algorithm -eq "cryptonightv8") {
						$add = "--variant 2"
					}
				}
				if ($extrargs -notmatch "-a ") {
					switch ($_.Algorithm) {
						"cryptolight" { $add = Get-Join " " @($add, "-a cryptonight-lite") }
						"cryptonightv7" { $add = Get-Join " " @($add, "-a cryptonight") }
						"cryptonightv8" { $add = Get-Join " " @($add, "-a cryptonight") }
						"cryptonightheavy" { $add = Get-Join " " @($add, "-a cryptonight-heavy") }
					}
				}
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::CPU
					API = "xmrig"
					URI = $url
					Path = "$Name\xmrig.exe"
					ExtraArgs = $extrargs
					Arguments = "-o $($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -R $($Config.CheckTimeout) --api-port=4045 --donate-level=1 --cpu-priority 0 $add $extrargs"
					Port = 4045
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = 1
				}
			}
		}
	}
}