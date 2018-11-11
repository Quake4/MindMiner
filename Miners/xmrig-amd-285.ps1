<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::AMD) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $true
	BenchmarkSeconds = 120
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptolight"; ExtraArgs = "-a cryptonight-lite" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightheavy"; ExtraArgs = "-a cryptonight-heavy" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightv7"; ExtraArgs = "-a cryptonight" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightv8"; ExtraArgs = "-a cryptonight" }
)})

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
				$variant = "--variant 1"
				if ($_.Algorithm -eq "cryptonightv8") {
					$variant = "--variant 2"
				}
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::AMD
					API = "xmrig"
					URI = "https://github.com/xmrig/xmrig-amd/releases/download/v2.8.5/xmrig-amd-2.8.5-win64.zip"
					Path = "$Name\xmrig-amd.exe"
					ExtraArgs = $extrargs
					Arguments = "-o $($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) --api-port=4044 $variant --donate-level=1 --opencl-platform=$([Config]::AMDPlatformId) -R $($Config.CheckTimeout) $extrargs"
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
