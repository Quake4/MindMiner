<#
MindMiner  Copyright (C) 2017-2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::AMD) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 90
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonight"; BenchmarkSeconds = 60 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonight"; ExtraArgs = "--forcecompute" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightv7"; BenchmarkSeconds = 60 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightv7"; ExtraArgs = "--forcecompute" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightv8"; BenchmarkSeconds = 60 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightv8"; ExtraArgs = "--forcecompute" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightheavy"; BenchmarkSeconds = 60 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightheavy"; ExtraArgs = "--forcecompute" }
)}

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
					$add = [string]::Empty
					if ($extrargs -notmatch "--algo=") {
						switch ($_.Algorithm) {
							"cryptonightv7" { $add = Get-Join " " @($add, "--algo=1") }
							"cryptonightv8" { $add = Get-Join " " @($add, "--algo=10") }
							"cryptonightheavy" { $add = Get-Join " " @($add, "--algo=2") }
						}
					}
					[MinerInfo]@{
						Pool = $Pool.PoolName()
						PoolKey = $Pool.PoolKey()
						Name = $Name
						Algorithm = $Algo
						Type = [eMinerType]::AMD
						API = "cast"
						URI = "http://www.gandalph3000.com/download/cast_xmr-vega-win64_180.zip"
						Path = "$Name\cast_xmr-vega.exe"
						ExtraArgs = $extrargs
						Arguments = "-S $($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -R --ratewatchdog $add $extrargs"
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