<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Include.ps1

if ([Config]::ActiveTypes -notcontains [eMinerType]::CPU) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $false
	BenchmarkSeconds = 60
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash" }
)})

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				if ($Pool.Name -contains "nicehash") {
					# CPU
					for ([int] $i = [Config]::Cores; $i -le [Config]::Threads; $i++) {
						$extrargs = Get-Join " " @($Cfg.ExtraArgs, "-t $i", $_.ExtraArgs)
						[MinerInfo]@{
							Pool = $Pool.PoolName()
							PoolKey = $Pool.PoolKey()
							Name = $Name
							Algorithm = $Algo
							Type = [eMinerType]::CPU
							API = "nheq"
							URI = "https://github.com/nicehash/nheqminer/releases/download/0.5c/Windows_x64_nheqminer-5c.zip"
							Path = "$Name\nheqminer.exe"
							ExtraArgs = $extrargs
							Arguments = "-l $($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -a 4100 $extrargs"
							Port = 4100
							BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
							RunBefore = $_.RunBefore
							RunAfter = $_.RunAfter
						}
					}

					# nVidia
					<# $extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
					[MinerInfo]@{
						Pool = $Pool.PoolName()
						PoolKey = $Pool.PoolKey()
						Name = $Name
						Algorithm = $Algo
						Type = [eMinerType]::nVidia
						API = "nheq"
						URI = "https://github.com/nicehash/nheqminer/releases/download/0.5c/Windows_x64_nheqminer-5c.zip"
						Path = "$Name\nheqminer.exe"
						ExtraArgs = $extrargs
						Arguments = "-l $($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -a 4101 -t 0 -cd $extrargs"
						Port = 4101
						BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
						RunBefore = $_.RunBefore
						RunAfter = $_.RunAfter
					}#>
				}
			}
		}
	}
}
