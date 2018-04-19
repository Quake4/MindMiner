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
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash" }
#	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash"; ExtraArgs = "" }
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
				[decimal] $fee = 2.5
				if ($Pool.Protocol.Contains("ssl")) {
					$fee = 2
				}
				$pass = Get-PasswordString $Algo $Pool.Password
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::AMD
					API = "claymore"
					URI = "https://github.com/Quake4/MindMinerPrerequisites/raw/master/AMD/Claymore/Claymore-ZCash-AMD-Miner-v12.6.zip"
					Path = "$Name\ZecMiner64.exe"
					ExtraArgs = "$($_.ExtraArgs)"
					Arguments = "-zpool $($Pool.Protocol)://$($Pool.Host):$($Pool.Port) -zwal $($Pool.User) -zpsw $pass -retrydelay $($Config.CheckTimeout) $($_.ExtraArgs)"
					Port = 3333
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					Fee = $fee
				}
			}
		}
	}
}