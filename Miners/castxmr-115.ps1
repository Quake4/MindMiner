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
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonight"; BenchmarkSeconds = 60 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonight"; ExtraArgs = "--forcecompute" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightv7"; ExtraArgs = "--algo=1"; BenchmarkSeconds = 60 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightv7"; ExtraArgs = "--algo=1 --forcecompute" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightheavy"; ExtraArgs = "--algo=2"; BenchmarkSeconds = 60 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightheavy"; ExtraArgs = "--algo=2 --forcecompute" }
		CryptoNight-Heavy
)})

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				# forcecompute only in win 10 
				if ($extrargs -notcontains "--forcecompute" -or ($extrargs -contains "--forcecompute" -and [Environment]::OSVersion.Version -ge [Version]::new(10, 0))) {
					[MinerInfo]@{
						Pool = $Pool.PoolName()
						PoolKey = $Pool.PoolKey()
						Name = $Name
						Algorithm = $Algo
						Type = [eMinerType]::AMD
						API = "cast"
						URI = "http://www.gandalph3000.com/download/cast_xmr-vega-win64_115.zip"
						Path = "$Name\cast_xmr-vega.exe"
						ExtraArgs = $extrargs
						Arguments = "-S $($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -R --fastjobswitch --ratewatchdog $extrargs"
						Port = 7777
						BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
						RunBefore = $_.RunBefore
						RunAfter = $_.RunAfter
						Fee = 1.5
					}
				}
			}
		}
	}
}