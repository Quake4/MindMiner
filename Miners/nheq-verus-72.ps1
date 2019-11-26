<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::CPU) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $true
	BenchmarkSeconds = 60
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "verus" }
)})

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				for ([int] $i = $Devices["CPU"].Cores; $i -le $Devices["CPU"].Threads; $i++) {
					$extrargs = Get-Join " " @($Cfg.ExtraArgs, "-t $i", $_.ExtraArgs)
					[MinerInfo]@{
						Pool = $Pool.PoolName()
						PoolKey = $Pool.PoolKey()
						Priority = $Pool.Priority
						Name = $Name
						Algorithm = $Algo
						Type = [eMinerType]::CPU
						API = "nheq_verus"
						URI = "https://github.com/VerusCoin/nheqminer/releases/download/0.7.2/nheqminer-Windows-v0.7.2.zip"
						Path = "$Name\nheqminer.exe"
						ExtraArgs = $extrargs
						Arguments = "-v -l $($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -a 4046 $extrargs"
						Port = 4046
						BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
						RunBefore = $_.RunBefore
						RunAfter = $_.RunAfter
					}
				}
			}
		}
	}
}