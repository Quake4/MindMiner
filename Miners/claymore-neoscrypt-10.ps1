<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Include.ps1

if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $true
	BenchmarkSeconds = 90
	Algorithms = @(
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "neoscrypt"; ExtraArgs="-powlim 50" }
)})

if (!$Cfg.Enabled) { return }

$file = [IO.Path]::Combine($BinLocation, $Name, "pools.txt")
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
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::AMD
					API = "claymore"
					URI = "https://github.com/Quake4/MindMinerPrerequisites/raw/master/AMD/Claymore/Claymore-NeoScrypt-AMD-Miner-v1.0.zip"
					Path = "$Name\NeoScryptMiner.exe"
					ExtraArgs = "$($_.ExtraArgs)"
					Arguments = "-pool stratum+tcp://$($Pool.Host):$($Pool.PortUnsecure) -wal $($Pool.User) -psw $($Pool.Password) -retrydelay 5 -wd 0 $($_.ExtraArgs)"
					Port = 3333
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					Fee = if ($_.ExtraArgs -and $_.ExtraArgs.ToLower().Contains("nofee")) { 0 } else { 2 }
				}
			}
		}
	}
}