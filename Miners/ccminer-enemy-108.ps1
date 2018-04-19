<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $true
	BenchmarkSeconds = 120
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x16r" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x16s" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "phi" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "bitcore" }
)})

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$N = Get-CCMinerStatsAvg $Algo $_
				$pass = Get-PasswordString $Algo $Pool.Password
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = if ($Algo -match "x16.") { "ccminer_woe" } else { "ccminer" }
					URI = "http://mindminer.online/miners/nVidia/enemy/z-enemy-1.08-release.zip"
					Path = "$Name\z-enemy.exe"
					ExtraArgs = $_.ExtraArgs
					Arguments = "-a $($_.Algorithm) -o stratum+tcp://$($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $pass -R $($Config.CheckTimeout) $N $($_.ExtraArgs)"
					Port = 4068
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					Fee = 1
				}
			}
		}
	}
}