<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::AMD) { exit }
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
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightv8"; ExtraArgs = "--algo=10"; BenchmarkSeconds = 60 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightv8"; ExtraArgs = "--algo=10 --forcecompute" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightheavy"; ExtraArgs = "--algo=2"; BenchmarkSeconds = 60 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightheavy"; ExtraArgs = "--algo=2 --forcecompute" }
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
				if ($extrargs -notmatch "--forcecompute" -or ($extrargs -match "--forcecompute" -and [Environment]::OSVersion.Version -ge [Version]::new(10, 0))) {
					[MinerInfo]@{
						Pool = $Pool.PoolName()
						PoolKey = $Pool.PoolKey()
						Name = $Name
						Algorithm = $Algo
						Type = [eMinerType]::AMD
						API = "cast"
						URI = "https://github.com/glph3k/cast_xmr/releases/download/V160/cast_xmr-vega-win64_160.zip"
						Path = "$Name\cast_xmr-vega.exe"
						ExtraArgs = $extrargs
						Arguments = "-S $($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -R --ratewatchdog $extrargs"
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
