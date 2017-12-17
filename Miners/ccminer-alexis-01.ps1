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
	BenchmarkSeconds = 60
	Algorithms = @(
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "blake2s" }
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "blakecoin" }
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "keccak" }
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lbry" }
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2v2"; BenchmarkSeconds = 100 }
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "myr-gr" }
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "neoscrypt" }
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "neoscrypt"; ExtraArgs = "-i 15" }
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "nist5" }
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sib" }
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sib"; ExtraArgs = "-i 21" }
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "skein" }
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "c11" }
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "c11"; ExtraArgs = "-i 21" }
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x17" }
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x17"; ExtraArgs = "-i 21" }
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "veltor" }
)})

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "ccminer"
					URI = "https://github.com/nemosminer/ccminer-Alexis78/releases/download/ccminer-alexis78/ccminer-alexis78-ms2013-cuda7.5.7z"
					Path = "$Name\ccminer.exe"
					ExtraArgs = $_.ExtraArgs
					Arguments = "-a $($_.Algorithm) -o stratum+tcp://$($Pool.Host):$($Pool.Port) -u $($Pool.User) -p $($Pool.Password) $($_.ExtraArgs)"
					Port = 4068
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
				}
			}
		}
	}
}
