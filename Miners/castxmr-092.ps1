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
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonight"; BenchmarkSeconds = 60 }
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonight"; ExtraArgs = "--forcecompute" }
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightv7"; BenchmarkSeconds = 60 }
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightv7"; ExtraArgs = "--forcecompute" }
)})

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				# forcecompute only in win 10 
				if (!$_.ExtraArgs -or $_.ExtraArgs -notcontains "--forcecompute" -or ($_.ExtraArgs -contains "--forcecompute" -and [Environment]::OSVersion.Version -ge [Version]::new(10, 0))) {
					$pass = Get-PasswordString $Algo $Pool.Password
					[MinerInfo]@{
						Pool = $Pool.PoolName()
						PoolKey = $Pool.PoolKey()
						Name = $Name
						Algorithm = $Algo
						Type = [eMinerType]::AMD
						API = "cast"
						URI = "http://www.gandalph3000.com/download/cast_xmr-vega-win64_092.zip"
						Path = "$Name\cast_xmr-vega.exe"
						ExtraArgs = "$($_.ExtraArgs)"
						Arguments = "-S $($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $pass -R --fastjobswitch $($_.ExtraArgs)"
						Port = 7777
						BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
						Fee = 1.5
					}
				}
			}
		}
	}
}