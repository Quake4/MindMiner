<#
MindMiner  Copyright (C) 2018-2022  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::AMD) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 90
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "0x10" }
)}

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				if ($_.Algorithm -eq "veil") { $_.Algorithm = "x16rt" }
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				$hosts = [string]::Empty
				$Pool.Hosts | ForEach-Object {
					$hosts = Get-Join " " @($hosts, "-o $_`:$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password)")
				}
				$fee = 1
				if ($_.Algorithm -match "heavyhash" -or $_.Algorithm -match "0x10") { $fee = 2 }
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Priority = $Pool.Priority
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::AMD
					TypeInKey = $true
					API = "xmrig"
					URI = "https://github.com/andru-kun/wildrig-multi/releases/download/0.31.3/wildrig-multi-windows-0.31.3.7z"
					Path = "$Name\wildrig.exe"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) $hosts -R $($Config.CheckTimeout) --opencl-platform=$([Config]::AMDPlatformId) --no-nvml --api-port=4028 --donate-level=1 $extrargs"
					Port = 4028
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = $fee
				}
			}
		}
	}
}