<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::AMD) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 120
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptolight" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightheavy" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightv7" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightv8" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightr" }
)}

if (!$Cfg.Enabled) { return }

$file = [IO.Path]::Combine($BinLocation, $Name, "config.json")
if ([IO.File]::Exists($file)) {
	[IO.File]::Delete($file)
}

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
					if ($_.Algorithm -eq "cryptonightr") {
						$add = "--variant 4"
					}
				}
				if ($extrargs -notmatch "-a ") {
					switch ($_.Algorithm) {
						"cryptolight" { $add = Get-Join " " @($add, "-a cryptonight-lite") }
						"cryptonightv7" { $add = Get-Join " " @($add, "-a cryptonight") }
						"cryptonightv8" { $add = Get-Join " " @($add, "-a cryptonight") }
						"cryptonightr" { $add = Get-Join " " @($add, "-a cryptonight") }
						"cryptonightheavy" { $add = Get-Join " " @($add, "-a cryptonight-heavy") }
					}
				}
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::AMD
					API = "xmrig"
					URI = "https://github.com/xmrig/xmrig-amd/releases/download/v2.14.1/xmrig-amd-2.14.1-msvc-win64.zip"
					Path = "$Name\xmrig-amd.exe"
					ExtraArgs = $extrargs
					Arguments = "-o $($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) --api-port=4044 --donate-level=1 --opencl-platform=$([Config]::AMDPlatformId) -R $($Config.CheckTimeout) $add $extrargs"
					Port = 4044
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = 1
				}
			}
		}
	}
}
