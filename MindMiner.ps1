<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Out-Data.ps1

Out-Iam
Write-Host "Loading ..." -ForegroundColor Green

. .\Code\Include.ps1

# ctrl+c hook
[Console]::TreatControlCAsInput = $true

$BinLocation = [IO.Path]::Combine($(Get-Location), [Config]::BinLocation)
New-Item $BinLocation -ItemType Directory -Force | Out-Null
$BinScriptLocation = [scriptblock]::Create("Set-Location('$BinLocation')")
$DownloadJob = $null

# download prerequisites
Get-Prerequisites ([Config]::BinLocation)

# read and validate config
$Config = Get-Config

if (!$Config) { exit }

Clear-Host
Out-Header

$ActiveMiners = [Collections.Generic.Dictionary[string, MinerProcess]]::new()
[SummaryInfo] $Summary = [SummaryInfo]::new([Config]::RateTimeout)
[StatCache] $Statistics = [StatCache]::Read()
$Summary.TotalTime.Start()

# FastLoop - variable for benchmark or miner errors - very fast switching to other miner - without ask pools and miners
[bool] $FastLoop = $false 
# exit - var for exit
[bool] $exit = $false
# main loop
while ($true)
{
	if ($Summary.RateTime.IsRunning -eq $false -or $Summary.RateTime.Elapsed.TotalSeconds -ge [Config]::RateTimeout.TotalSeconds) {
		# Get-RateInfo
		$exit = Update-Miner ([Config]::BinLocation)
		if ($exit -eq $true) {
			$FastLoop = $true
		}
		$Summary.RateTime.Reset()
		$Summary.RateTime.Start()
	}

	if (!$FastLoop) {
		# read algorithm mapping
		$AllAlgos = <#[BaseConfig]::ReadOrCreate("Algo" + [BaseConfig]::Filename,#> @{
			# how to map algorithms
			Mapping = [ordered]@{
				"blakecoin" = "Blake"
				"blake256r8" = "Blake"
				"daggerhashimoto" = "Ethash"
				"lyra2rev2" = "Lyra2re2"
				"lyra2r2" = "Lyra2re2"
				"lyra2v2" = "Lyra2re2"
				"m7m" = "M7M"
				"neoscrypt" = "NeoScrypt"
				"sib" = "X11Gost"
				"sibcoin" = "X11Gost"
				"sibcoin-mod" = "X11Gost"
				"skeincoin" = "Skein"
				"x11gost" = "X11Gost"
				"x11evo" = "X11Evo"
				"phi1612" = "Phi"
				"timetravel10" = "Bitcore"
				"x13sm3" = "Hsr"
				"myriad-groestl" = "MyrGr"
				"myriadgroestl" = "MyrGr"
				"myr-gr" = "MyrGr"
				"jackpot" = "JHA"
			}
			# disable asic algorithms
			Disabled = @("sha256", "scrypt", "x11", "x13", "x14", "x15", "quark", "qubit")
		} #)

		Write-Host "Pool(s) request ..." -ForegroundColor Green
		$AllPools = Get-PoolInfo "Pools"

		# check pool exists
		if (!$AllPools -or $AllPools.Length -eq 0) {
			Write-Host "No Pools!" -ForegroundColor Red
			Start-Sleep $Config.CheckTimeout
			continue
		}
		
		Write-Host "Miners request ..." -ForegroundColor Green
		$AllMiners = Get-ChildItem "Miners" | Where-Object Extension -eq ".ps1" | ForEach-Object {
			Invoke-Expression "Miners\$($_.Name)"
		}

		# filter by exists hardware
		$AllMiners = $AllMiners | Where-Object { [array]::IndexOf([Config]::ActiveTypes, ($_.Type -as [eMinerType])) -ge 0 }

		# download miner
		if (!(Get-Job -State Running) -and $DownloadJob) {
			Remove-Job -Name "Download"
			$DownloadJob = $null
		}
		$DownloadMiners = $AllMiners | Where-Object { !$_.Exists([Config]::BinLocation) } | Select-Object Path, URI -Unique | ForEach-Object { @{ Path = $_.Path; URI = $_.URI } }
		if ($DownloadMiners.Length -gt 0) {
			Write-Host "Download $($DownloadMiners.Length) miner(s) ... " -ForegroundColor Green
			if (!(Get-Job -State Running)) {
				Start-Job -Name "Download" -ArgumentList $DownloadMiners -FilePath ".\Code\Downloader.ps1" -InitializationScript $BinScriptLocation | Out-Null
				$DownloadJob = $true
			}
		}

		# check exists miners
		$AllMiners = $AllMiners | Where-Object { $_.Exists([Config]::BinLocation) }
		
		if ($AllMiners.Length -eq 0) {
			Write-Host "No Miners!" -ForegroundColor Red
			Start-Sleep $Config.CheckTimeout
			continue
		}

		# save speed active miners
		$ActiveMiners.Values | Where-Object { $_.State -eq [eState]::Running -and $_.Action -eq [eAction]::Normal } | ForEach-Object {
			$speed = $_.GetSpeed()
			if ($speed -gt 0) {
				$speed = $Statistics.SetValue($_.Miner.GetFilename(), $_.Miner.GetKey(), $speed, $Config.AverageHashSpeed, 0.25)
			}
			elseif ($speed -eq 0 -and $_.CurrentTime.Elapsed.TotalSeconds -ge $Config.LoopTimeout) {
				# no hasrate stop miner and move to nohashe state while not ended
				$_.Stop()
			}
		}
	}

	# stop benchmark by condition: timeout reached and has result or timeout more 5 and no result
	$ActiveMiners.Values | Where-Object { $_.State -eq [eState]::Running -and $_.Action -eq [eAction]::Benchmark } | ForEach-Object {
		$speed = $_.GetSpeed()
		if (($_.CurrentTime.Elapsed.TotalSeconds -ge $_.Miner.BenchmarkSeconds -and $speed -gt 0) -or
			($_.CurrentTime.Elapsed.TotalSeconds -ge ($_.Miner.BenchmarkSeconds * 2) -and $speed -eq 0)) {
				$_.Stop()
			if ($speed -eq 0) {
				$speed = $Statistics.SetValue($_.Miner.GetFilename(), $_.Miner.GetKey(), -1)
			}
			else {
				$speed = $Statistics.SetValue($_.Miner.GetFilename(), $_.Miner.GetKey(), $speed, $Config.AverageHashSpeed)
			}
		}
	}
	
	# read speed and price of proposed miners
	$AllMiners = $AllMiners | ForEach-Object {
		if (!$FastLoop) {
			$speed = $Statistics.GetValue($_.GetFilename(), $_.GetKey())
			# filter unused
			if ($speed -ge 0) {
				$price = (Get-Pool $_.Algorithm).Profit
				[MinerProfitInfo]::new($_, $speed, $price)
				Remove-Variable price
			}
		}
		elseif (!$exit) {
			$speed = $Statistics.GetValue($_.Miner.GetFilename(), $_.Miner.GetKey())
			# filter unused
			if ($speed -ge 0) {
				$_.SetSpeed($speed)
				$_
			}
		}
	}

	if (!$exit) {
		Remove-Variable speed
	
		# look for run or stop miner
		[Config]::ActiveTypes | ForEach-Object {
			$type = $_

			$allMinersByType = $AllMiners | Where-Object { $_.Miner.Type -eq $type }
			$activeMinersByType = $ActiveMiners.Values | Where-Object { $_.Miner.Type -eq $type }

			# run for bencmark - exclude failed
			$run = $allMinersByType | Where-Object { $Statistics.GetValue($_.Miner.GetFilename(), $_.Miner.GetKey()) -eq 0 } | Select-Object -First 1

			# nothing benchmarking - get most profitable - exclude failed
			if (!$run) {
				$miner = $null
				$allMinersByType | Where-Object { $_.Profit -gt 0 } | ForEach-Object {
					if ($run -eq $null -or $_.Profit -gt $run.Profit) {
						# skip failed or nohash miners
						$miner = $_
						if (($activeMinersByType | Where-Object { $_.State -eq [eState]::NoHash -or $_.State -eq [eState]::Failed } |
							Where-Object { $miner.Miner.GetUniqueKey() -eq $_.Miner.GetUniqueKey() }) -eq $null) {
							$run = $_
						}
					}
				}
				Remove-Variable miner
			}

			if ($run) {
				$miner = $run.Miner
				if (!$ActiveMiners.ContainsKey($miner.GetUniqueKey())) {
					$ActiveMiners.Add($miner.GetUniqueKey(), [MinerProcess]::new($miner, $Config))
				}
				#stop not choosen
				$activeMinersByType | Where-Object { $miner.GetUniqueKey() -ne $_.Miner.GetUniqueKey() } | ForEach-Object {
					$_.Stop()
				}
				# run choosen
				$mi = $ActiveMiners[$miner.GetUniqueKey()]
				if ($mi.State -eq $null -or $mi.State -ne [eState]::Running) {
					if ($Statistics.GetValue($mi.Miner.GetFilename(), $mi.Miner.GetKey()) -eq 0) {
						$mi.Benchmark()
					}
					else {
						$mi.Start()
					}
					$FastLoop = $false
				}
				Remove-Variable mi, miner
			}
			Remove-Variable run, activeMinersByType, allMinersByType, type
		}
	}
	
	$Statistics.Write()

	if (!$FastLoop) {
		$Summary.LoopTime.Reset()
		$Summary.LoopTime.Start()
	}

	Clear-Host
	Out-Header

	$verbose = $Config.Verbose -as [eVerbose]

	if ($verbose -ne [eVerbose]::Minimal) {
		Out-PoolInfo
	}
	
	$AllMiners | Where-Object { $_.Speed -eq 0 -or $true <# $verbose -eq [eVerbose]::Full #> } |
		Sort-Object @{ Expression = { $_.Miner.Type } },
			@{ Expression = { $_.Profit }; Descending = $true },
			@{ Expression = { $_.Miner.Algorithm } },
			@{ Expression = { $_.Miner.ExtraArgs } } |
		Format-Table @{ Label="Miner"; Expression = {
				$uniq =  $_.Miner.GetUniqueKey()
				$str = [string]::Empty
				($ActiveMiners.Values | Where-Object { $_.State -ne [eState]::Stopped } | ForEach-Object {
					if ($_.Miner.GetUniqueKey() -eq $uniq) {
						if ($_.State -eq [eState]::Running) { $str = "*" } elseif ($_.State -eq [eState]::NoHash) { $str = "-" } elseif ($_.State -eq [eState]::Failed) { $str = "!" } } })
				$str + $_.Miner.Name } },
			@{ Label="Algorithm"; Expression = { $_.Miner.Algorithm } },
			@{ Label="Speed, H/s"; Expression = { if ($_.Speed -eq 0) { "Testing" } else { [MultipleUnit]::ToString($_.Speed) } }; Alignment="Right" },
			@{ Label="mBTC/Day"; Expression = { if ($_.Speed -eq 0) { "$($_.Miner.BenchmarkSeconds) sec" } else { $_.Profit * 1000 } }; FormatString = "N5" },
			@{ Label="BTC/GH/Day"; Expression = { $_.Price * 1000000000 }; FormatString = "N8" },
			@{ Label="Pool"; Expression = { $_.Miner.Pool } },
			@{ Label="ExtraArgs"; Expression = { $_.Miner.ExtraArgs } } -GroupBy @{ Label="Type"; Expression = { $_.Miner.Type } } | Out-Host
	Write-Host "* Running, - NoHash, ! Failed"
	Write-Host ""

	# display active miners
	$ActiveMiners.Values | Where-Object { $verbose -ne [eVerbose]::Minimal } |
		Sort-Object { [int]($_.State -as [eState]), [SummaryInfo]::Elapsed($_.TotalTime.Elapsed) } |
		Format-Table @{ Label="Type"; Expression = { $_.Miner.Type } },
			@{ Label="Algorithm"; Expression = { $_.Miner.Algorithm } },
			@{ Label="Speed, H/s"; Expression = { $speed = $_.GetSpeed(); if ($speed -eq 0) { "Unknown" } else { [MultipleUnit]::ToString($speed) } }; Alignment="Right"; },
			@{ Label="Run Time"; Expression = { [SummaryInfo]::Elapsed($_.TotalTime.Elapsed) }; Alignment = "Right" },
			@{ Label="Run"; Expression = { if ($_.Run -eq 1) { "Once" } else { $_.Run } } },
			@{ Label="Command"; Expression = { $_.Miner.GetCommandLine() } } -GroupBy State -Wrap | Out-Host

	Remove-Variable verbose

	Out-Footer

	do {
		$FastLoop = $false

		$start = [datetime]::Now
		do {
			Start-Sleep -Milliseconds 100
			while ([Console]::KeyAvailable -eq $true) {
				[ConsoleKeyInfo] $key = [Console]::ReadKey($true)
				if ($key.Key -eq [ConsoleKey]::V) {
					$items = [enum]::GetValues([eVerbose])
					$index = [array]::IndexOf($items, $Config.Verbose -as [eVerbose]) + 1
					$Config.Verbose = if ($items.Length -eq $index) { $items[0] } else { $items[$index] }
					Remove-Variable index, items
					Write-Host "Verbose level changed to $($Config.Verbose)." -ForegroundColor Green
					$FastLoop = $true
				}
				elseif ($key.Modifiers -match [ConsoleModifiers]::Alt -or $key.Modifiers -match [ConsoleModifiers]::Control) {
					if ($key.Key -eq [ConsoleKey]::C -or $key.Key -eq [ConsoleKey]::E -or $key.Key -eq [ConsoleKey]::Q -or $key.Key -eq [ConsoleKey]::X) {
						$exit = $true
					}
				}
			}
		} while (([datetime]::Now - $start).TotalSeconds -lt $Config.CheckTimeout -and !$exit -and !$FastLoop)
		Remove-Variable start

		# if needed - exit
		if ($exit -eq $true) {
			Write-Host "Exiting ..." -ForegroundColor Green
			$ActiveMiners.Values | Where-Object { $_.State -eq [eState]::Running } | ForEach-Object {
				$_.Stop()
			}
			exit
		}

		# read speed while run main loop timeout
		if ($ActiveMiners.Values -and $ActiveMiners.Values.Length -gt 0) {
			Get-Speed $ActiveMiners.Values
		}
		# check miners work propertly
		$ActiveMiners.Values | Where-Object { $_.State -eq [eState]::Running -or $_.State -eq [eState]::NoHash } | ForEach-Object {
			if ($_.Check() -eq [eState]::Failed) {
				# miner failed - run next
				if ($_.Action -eq [eAction]::Benchmark) {
					$speed = $Statistics.SetValue($_.Miner.GetFilename(), $_.Miner.GetKey(), -1)
					Remove-Variable speed
				}
				$FastLoop = $true
			}
			# benchmark time reached - exit from loop
			elseif ($_.Action -eq [eAction]::Benchmark) {
				$speed = $_.GetSpeed()
				if (($_.CurrentTime.Elapsed.TotalSeconds -ge $_.Miner.BenchmarkSeconds -and $speed -gt 0) -or
					($_.CurrentTime.Elapsed.TotalSeconds -ge ($_.Miner.BenchmarkSeconds * 2) -and $speed -eq 0)) {
					$FastLoop = $true
				}
				Remove-Variable speed
			}
		}
	} while ($Config.LoopTimeout -gt $Summary.LoopTime.Elapsed.TotalSeconds -and !$FastLoop)

	# if timeout reached - normal loop
	if ($Config.LoopTimeout -le $Summary.LoopTime.Elapsed.TotalSeconds) {
		$FastLoop = $false
	}

	if (!$FastLoop) {
		Remove-Variable AllPools, AllMiners
		[GC]::Collect()
	}
	
	$Summary.Loop++
}