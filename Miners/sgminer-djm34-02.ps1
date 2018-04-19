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
	BenchmarkSeconds = 45
	Algorithms = @(
		#[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2rev2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2z"; ExtraArgs="-I 18 -w 32" }
		#[AlgoInfoEx]@{ Enabled = $true; Algorithm = "skein" }
		#[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yescrypt" }
	)
})

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
					Type = [eMinerType]::AMD
					API = "sgminer"
					URI = "https://github.com/djm34/sgminer-msvc2015/releases/download/v0.2-pre/kernel_and_binary.rar"
					Path = "$Name\sgminer.exe"
					ExtraArgs = $_.ExtraArgs
					Arguments = "-k $($_.Algorithm) -o stratum+tcp://$($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $pass --api-listen $($_.ExtraArgs)"
					Port = 4028
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
				}
			}
		}
	}
}
