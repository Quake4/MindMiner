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
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash" }
)})

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$proto = $Pool.Protocol
				if (!$Pool.Protocol.Contains("ssl")) {
					$proto = "stratum"
				}
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "bminer"
					URI = "https://github.com/Quake4/MindMinerPrerequisites/raw/master/nVidia/bminer/bminer-v5.2.0-amd64.zip"
					Path = "$Name\bminer.exe"
					ExtraArgs = $_.ExtraArgs
					Arguments = "-uri $proto`://$($Pool.User):$($Pool.Password)@$($Pool.Host):$($Pool.Port) -api 127.0.0.1:1880 $($_.ExtraArgs)"
					Port = 1880
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					Fee = 2
				}
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "bminer"
					URI = "https://github.com/Quake4/MindMinerPrerequisites/raw/master/nVidia/bminer/bminer-v5.2.0-amd64.zip"
					Path = "$Name\bminer.exe"
					ExtraArgs = "-nofee $($_.ExtraArgs)".Trim()
					Arguments = "-uri $proto`://$($Pool.User):$($Pool.Password)@$($Pool.Host):$($Pool.Port) -api 127.0.0.1:1880 -nofee $($_.ExtraArgs)"
					Port = 1880
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
				}
			}
		}
	}
}