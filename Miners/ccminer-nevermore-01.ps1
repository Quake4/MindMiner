<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $true
	BenchmarkSeconds = 90
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x16r" }
)})

if (!$Cfg.Enabled) { return }

if ([Config]::Is64Bit -eq $true) {
	$url = "https://github.com/brian112358/nevermore-miner/releases/download/v0.1-alpha/nevermore-v0.1-alpha-win64-fixed.zip"
}
else {
	$url = "https://github.com/brian112358/nevermore-miner/releases/download/v0.1-alpha/nevermore-v0.1-alpha-win32-fixed.zip"
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
					Type = [eMinerType]::nVidia
					API = "ccminer"
					URI = $url
					Path = "$Name\ccminer.exe"
					ExtraArgs = $_.ExtraArgs
					Arguments = "-a $($_.Algorithm) -o stratum+tcp://$($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -R 5 -N 3 $($_.ExtraArgs)"
					Port = 4068
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					Fee = 1
				}
			}
		}
	}
}
