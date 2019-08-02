<#
MindMiner  Copyright (C) 2018-2019  Oleg Samsonov aka Quake4
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
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "blake2b-btcc" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "blake2b-glt" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "blake2s" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "bmw512" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2v3" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2vc0ban" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "skein2" }
)}

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool -and ($Pool.Name -notmatch "nicehash" -or ($Pool.Name -match "nicehash" -and $_.Algorithm -notmatch "mtp"))) {
				if ($_.Algorithm -match "veil") { $_.Algorithm = "x16rt" }
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::AMD
					API = "xmrig"
					URI = "https://github.com/andru-kun/wildrig-multi/releases/download/0.19.0/wildrig-multi-windows-0.19.0-preview.7z"
					Path = "$Name\wildrig.exe"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) -o $($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -R $($Config.CheckTimeout) --opencl-platform=$([Config]::AMDPlatformId) --api-port=4028 --donate-level=1 $extrargs"
					Port = 4028
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = 1
				}
			}
		}
	}
}