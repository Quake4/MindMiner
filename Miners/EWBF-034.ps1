<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Include.ps1

if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $false
	BenchmarkSeconds = 60
	Algorithms = @(
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash" }
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash"; ExtraArgs = "--solver 0" }
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash"; ExtraArgs = "--solver 1" }
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash"; ExtraArgs = "--solver 2" }
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash"; ExtraArgs = "--solver 3" }
)})

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$pass = Get-PasswordString $Algo $Pool.Password
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "ewbf"
					URI = "https://github.com/nanopool/ewbf-miner/releases/download/v0.3.4b/Zec.miner.0.3.4b.zip"
					Path = "$Name\miner.exe"
					ExtraArgs = $_.ExtraArgs
					Arguments = "--api --server $($Pool.Host) --user $($Pool.User) --pass $pass --port $($Pool.PortUnsecure) --eexit 1 $($_.ExtraArgs)"
					Port = 42000
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					Fee = 2
				}
			}
		}
	}
}