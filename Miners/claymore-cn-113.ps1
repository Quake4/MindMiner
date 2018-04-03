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
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonight" }
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptolite"; ExtraArgs = "-lite" }
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightv7"; ExtraArgs = "-pow7 1" }
)})

if (!$Cfg.Enabled) { return }

$file = [IO.Path]::Combine($BinLocation, $Name, "epools.txt")
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
					URI = "https://github.com/Quake4/MindMinerPrerequisites/raw/master/AMD/Claymore/Claymore-CryptoNote-AMD-Miner-v11.3.zip"
					Path = "$Name\NsGpuCNMiner.exe"
					ExtraArgs = "$($_.ExtraArgs)"
					Arguments = "-xpool $($Pool.Protocol)://$($Pool.Host):$($Pool.Port) -xwal $($Pool.User) -xpsw $($Pool.Password) -retrydelay $($Config.CheckTimeout) $($_.ExtraArgs)"
					Port = 3333
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
				}
			}
		}
	}
}