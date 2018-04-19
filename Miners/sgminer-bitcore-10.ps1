<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $true
	BenchmarkSeconds = 90
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "timetravel10"; ExtraArgs="-I 19" } #570?
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "timetravel10"; ExtraArgs="-I 22" } #580
		#[AlgoInfoEx]@{ Enabled = $true; Algorithm = "timetravel10"; ExtraArgs="-I 25" } #vega?
	)
})

if (!$Cfg.Enabled) { return }

if ([Config]::Is64Bit -eq $true) {
	$file = "sgminer-x64.exe"
}
else {
	$file = "sgminer.exe"
}

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
					Type = [eMinerType]::AMD
					API = "sgminer"
					URI = "https://github.com/Quake4/MindMinerPrerequisites/raw/master/AMD/sgminer-bitcore/sgminer-bitcore-5.6.1.9.zip"
					Path = "$Name\$file"
					ExtraArgs = $_.ExtraArgs
					Arguments = "-k $($_.Algorithm) -o stratum+tcp://$($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $pass --api-listen --gpu-platform $([Config]::AMDPlatformId) $($_.ExtraArgs)"
					Port = 4028
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
				}
			}
		}
	}
}