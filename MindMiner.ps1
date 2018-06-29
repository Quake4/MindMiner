<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Out-Data.ps1

Out-Iam
Write-Host "Loading ..." -ForegroundColor Green

$global:HasConfirm = $false
$global:NeedConfirm = $false
$global:API = [hashtable]::Synchronized(@{})

. .\Code\Include.ps1

# ctrl+c hook
[Console]::TreatControlCAsInput = $true
[Console]::Title = "MindMiner $([Config]::Version.Replace("v", [string]::Empty))"

$BinLocation = [IO.Path]::Combine($(Get-Location), [Config]::BinLocation)
New-Item $BinLocation -ItemType Directory -Force | Out-Null
$BinScriptLocation = [scriptblock]::Create("Set-Location('$BinLocation')")
$DownloadJob = $null

# download prerequisites
Get-Prerequisites ([Config]::BinLocation)

# read and validate config
$Config = Get-Config

if (!$Config) { exit }

[SummaryInfo] $Summary = [SummaryInfo]::new([Config]::RateTimeout)
$Summary.TotalTime.Start()

Clear-Host
Out-Header

$ActiveMiners = [Collections.Generic.Dictionary[string, MinerProcess]]::new()
[StatCache] $Statistics = [StatCache]::Read([Config]::StatsLocation)
if ($Config.ApiServer) {
	if ([Net.HttpListener]::IsSupported) {
		if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
			Write-Host "Starting API server at port $([Config]::ApiPort) for Remote access ..." -ForegroundColor Green
		}
		else {
			Write-Host "Starting API server at port $([Config]::ApiPort) for Local access ..." -ForegroundColor Green
			Write-Host "To start API server for remote access run MindMiner as Administrator." -ForegroundColor Yellow
		}
		Start-ApiServer
	}
	else {
		Write-Host "Http listner not supported. Can't start API server." -ForegroundColor Red
	}
}

if ($global:API.Running) {
	$global:API.Worker = $Config.WorkerName
	$global:API.Config = $Config.Web() | ConvertTo-Html -Fragment
}

# FastLoop - variable for benchmark or miner errors - very fast switching to other miner - without ask pools and miners
[bool] $FastLoop = $false 
# exit - var for exit
[bool] $exit = $false
# main loop
while ($true)
{
	# reset NeedConfirm and FastLoop after user confirm
	if ($FastLoop -eq $true -and $global:HasConfirm -eq $true -and $global:NeedConfirm -eq $true) {
		$FastLoop = $false
		$global:NeedConfirm = $false
	}

	if ($Summary.RateTime.IsRunning -eq $false -or $Summary.RateTime.Elapsed.TotalSeconds -ge [Config]::RateTimeout.TotalSeconds) {
		$Rates = Get-RateInfo
		$exit = Update-Miner ([Config]::BinLocation)
		if ($exit -eq $true) {
			$FastLoop = $true
		}
		$Summary.RateTime.Reset()
		$Summary.RateTime.Start()
	}
	elseif (!$Rates -or $Rates.Count -eq 0) {
		$Rates = Get-RateInfo
	}

	if (!$FastLoop) {
		# read algorithm mapping
		$AllAlgos = [BaseConfig]::ReadOrCreate("algorithms.txt", @{
			EnabledAlgorithms = $null
			DisabledAlgorithms = $null
			Difficulty = $null
			RunBefore = $null
			RunAfter = $null
		})
		# how to map algorithms
		$AllAlgos.Add("Mapping", [ordered]@{
			"aeriumx" = "Aergo"
			"blakecoin" = "Blake"
			"blake256r8" = "Blake"
			"cryptonight_heavy" = "Cryptonightheavy"
			"cryptonight_v7" = "Cryptonightv7"
			"cryptonight_lite_v7" = "Cryptolightv7"
			"daggerhashimoto" = "Ethash"
			"lyra2rev2" = "Lyra2re2"
			"lyra2r2" = "Lyra2re2"
			"lyra2v2" = "Lyra2re2"
			"monero" = "Cryptonightv7"
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
			"vit" = "Vitalium"
		})
		# disable asic algorithms
		$AllAlgos.Add("Disabled", @("sha256", "scrypt", "x11", "x13", "x14", "x15", "quark", "qubit", "myrgr", "lbry", "decred", "blake", "nist5", "cryptonight", "x11gost", "groestl"))

		Write-Host "Pool(s) request ..." -ForegroundColor Green
		$AllPools = Get-PoolInfo ([Config]::PoolsLocation)

		# check pool exists
		if (!$AllPools -or $AllPools.Length -eq 0) {
			Write-Host "No Pools!" -ForegroundColor Red
			Get-Confirm
			continue
		}
		
		Write-Host "Miners request ..." -ForegroundColor Green
		$AllMiners = Get-ChildItem ([Config]::MinersLocation) | Where-Object Extension -eq ".ps1" | ForEach-Object {
			Invoke-Expression "$([Config]::MinersLocation)\$($_.Name)"
		}

		# filter by exists hardware
		$AllMiners = $AllMiners | Where-Object { [Config]::ActiveTypes -contains ($_.Type -as [eMinerType]) }

		# download miner
		if ($DownloadJob -and $DownloadJob.State -ne "Running") {
			$DownloadJob | Remove-Job -Force | Out-Null
			$DownloadJob.Dispose()
			$DownloadJob = $null
		}
		$DownloadMiners = $AllMiners | Where-Object { !$_.Exists([Config]::BinLocation) } | Select-Object Path, URI -Unique | ForEach-Object { @{ Path = $_.Path; URI = $_.URI } }
		if ($DownloadMiners.Length -gt 0) {
			Write-Host "Download $($DownloadMiners.Length) miner(s) ... " -ForegroundColor Green
			if (!$DownloadJob) {
				$DownloadJob = Start-Job -ArgumentList $DownloadMiners -FilePath ".\Code\Downloader.ps1" -InitializationScript $BinScriptLocation
			}
		}

		# check exists miners & update bench timeout by global value
		$AllMiners = $AllMiners | Where-Object { $_.Exists([Config]::BinLocation) } | ForEach-Object {
			if ($Config.BenchmarkSeconds -and $Config.BenchmarkSeconds."$($_.Type)" -gt $_.BenchmarkSeconds) {
				$_.BenchmarkSeconds = $Config.BenchmarkSeconds."$($_.Type)"
			}
			$_
		}
		
		if ($AllMiners.Length -eq 0) {
			Write-Host "No Miners!" -ForegroundColor Red
			Get-Confirm
			continue
		}

		# save speed active miners
		$ActiveMiners.Values | Where-Object { $_.State -eq [eState]::Running -and $_.Action -eq [eAction]::Normal } | ForEach-Object {
			$speed = $_.GetSpeed($false)
			if ($speed -gt 0) {
				$speed = $Statistics.SetValue($_.Miner.GetFilename(), $_.Miner.GetKey(), $speed, $Config.AverageHashSpeed, 0.25)
				if (![string]::IsNullOrWhiteSpace($_.Miner.DualAlgorithm)) {
					$speed = $_.GetSpeed($true)
					if ($speed -gt 0) {
						$speed = $Statistics.SetValue($_.Miner.GetFilename(), $_.Miner.GetKey($true), $speed, $Config.AverageHashSpeed, 0.25)
					}
				}
			}
			elseif ($speed -eq 0 -and $_.CurrentTime.Elapsed.TotalSeconds -ge ($_.Miner.BenchmarkSeconds * 2)) {
				# no hasrate stop miner and move to nohashe state while not ended
				$_.Stop($AllAlgos.RunAfter)
			}
		}
	}

	# stop benchmark by condition: timeout reached and has result or timeout more then twice and no result
	$Benchs = $ActiveMiners.Values | Where-Object { $_.State -eq [eState]::Running -and $_.Action -eq [eAction]::Benchmark }
	if ($Benchs) { Get-Speed $Benchs } # read speed from active miners
	$Benchs | ForEach-Object {
		$speed = $_.GetSpeed($false)
		if (($_.CurrentTime.Elapsed.TotalSeconds -ge $_.Miner.BenchmarkSeconds -and $speed -gt 0) -or
			($_.CurrentTime.Elapsed.TotalSeconds -ge ($_.Miner.BenchmarkSeconds * 2) -and $speed -eq 0)) {
			$_.Stop($AllAlgos.RunAfter)
			if ($speed -eq 0) {
				$speed = $Statistics.SetValue($_.Miner.GetFilename(), $_.Miner.GetKey(), -1)
			}
			else {
				$speed = $Statistics.SetValue($_.Miner.GetFilename(), $_.Miner.GetKey(), $speed, $Config.AverageHashSpeed)
				if (![string]::IsNullOrWhiteSpace($_.Miner.DualAlgorithm)) {
					$speed = $_.GetSpeed($true)
					$speed = $Statistics.SetValue($_.Miner.GetFilename(), $_.Miner.GetKey($true), $speed, $Config.AverageHashSpeed)
				}
			}
		}
	}
	Remove-Variable Benchs
	
	# read speed and price of proposed miners
	$AllMiners = $AllMiners | ForEach-Object {
		if (!$FastLoop) {
			$speed = $Statistics.GetValue($_.GetFilename(), $_.GetKey())
			# filter unused
			if ($speed -ge 0) {
				$price = (Get-Pool $_.Algorithm).Profit
				if (![string]::IsNullOrWhiteSpace($_.DualAlgorithm)) {
					[MinerProfitInfo]::new($_, $Config, $speed, $price, $Statistics.GetValue($_.GetFilename(), $_.GetKey($true)), (Get-Pool $_.DualAlgorithm).Profit)
				}
				else {
					[MinerProfitInfo]::new($_, $Config, $speed, $price)
				}
				Remove-Variable price
			}
		}
		elseif (!$exit) {
			$speed = $Statistics.GetValue($_.Miner.GetFilename(), $_.Miner.GetKey())
			# filter unused
			if ($speed -ge 0) {
				if (![string]::IsNullOrWhiteSpace($_.Miner.DualAlgorithm)) {
					$_.SetSpeed($speed, $Statistics.GetValue($_.Miner.GetFilename(), $_.Miner.GetKey($true)))
				}
				else {
					$_.SetSpeed($speed)
				}
				$_
			}
		}
	} |
	# reorder miners for proper output
	Sort-Object @{ Expression = { $_.Miner.Type } }, @{ Expression = { $_.Profit }; Descending = $true }, @{ Expression = { $_.Miner.GetExKey() } }

	if (!$exit) {
		Remove-Variable speed

		if ($global:HasConfirm -and !($AllMiners | Where-Object { $_.Speed -eq 0 } | Select-Object -First 1)) {
			# reset confirm after all bench
			$global:HasConfirm = $false
		}

		$FStart = !$global:HasConfirm -and ($Summary.TotalTime.Elapsed.TotalSeconds / 100 -gt $Summary.FeeTime.Elapsed.TotalSeconds + [Config]::FTimeout)
		$FChange = $false
		if ($FStart -or $Summary.FeeCurTime.IsRunning) {
			if (!$FStart -and $Summary.FeeCurTime.Elapsed.TotalSeconds -gt [Config]::FTimeout * 2) {
				$FChange = $true
				$Summary.FStop()
			}
			elseif (!$Summary.FeeCurTime.IsRunning) {
				$FChange = $true
				$Summary.FStart()
			}
		}
		
		# look for run or stop miner
		[Config]::ActiveTypes | ForEach-Object {
			$type = $_

			# variables
			$allMinersByType = $AllMiners | Where-Object { $_.Miner.Type -eq $type }
			$activeMinersByType = $ActiveMiners.Values | Where-Object { $_.Miner.Type -eq $type }
			$activeMinerByType = $activeMinersByType | Where-Object { $_.State -eq [eState]::Running }
			$activeMiner = if ($activeMinerByType) { $allMinersByType | Where-Object { $_.Miner.GetUniqueKey() -eq $activeMinerByType.Miner.GetUniqueKey() } } else { $null }

			# run for bencmark
			$run = $allMinersByType | Where-Object { $_.Speed -eq 0 } | Sort-Object @{ Expression = { $_.Miner.GetExKey() } } | Select-Object -First 1
			if ($global:HasConfirm -eq $false -and $run) {
				$run = $null
				$global:NeedConfirm = $true
			}

			# nothing benchmarking - get most profitable - exclude failed
			if (!$run) {
				$miner = $null
				$allMinersByType | ForEach-Object {
					if (!$run -and $_.Profit -gt 0) {
						# skip failed or nohash miners
						$miner = $_
						if (($activeMinersByType | 
							Where-Object { ($_.State -eq [eState]::NoHash -or $_.State -eq [eState]::Failed) -and
								$miner.Miner.GetUniqueKey() -eq $_.Miner.GetUniqueKey() }) -eq $null) {
							$run = $_
						}
					}
				}
				Remove-Variable miner
			}

			if ($run -and ($global:HasConfirm -or $FChange -or !$activeMinerByType -or ($activeMinerByType -and !$activeMiner) -or !$Config.SwitchingResistance.Enabled -or
				($Config.SwitchingResistance.Enabled -and ($activeMinerByType.CurrentTime.Elapsed.TotalMinutes -ge $Config.SwitchingResistance.Timeout -or
					($run.Profit * 100 / $activeMiner.Profit - 100) -gt $Config.SwitchingResistance.Percent)))) {
				$miner = $run.Miner
				if (!$ActiveMiners.ContainsKey($miner.GetUniqueKey())) {
					$ActiveMiners.Add($miner.GetUniqueKey(), [MinerProcess]::new($miner, $Config))
				}
				# stop not choosen
				$activeMinersByType | Where-Object { $_.State -eq [eState]::Running -and ($miner.GetUniqueKey() -ne $_.Miner.GetUniqueKey() -or $FChange) } | ForEach-Object {
					$_.Stop($AllAlgos.RunAfter)
				}
				# run choosen
				$mi = $ActiveMiners[$miner.GetUniqueKey()]
				if ($mi.State -eq $null -or $mi.State -ne [eState]::Running) {
					if ($Statistics.GetValue($mi.Miner.GetFilename(), $mi.Miner.GetKey()) -eq 0 -or $FStart) {
						$mi.Benchmark($FStart, $AllAlgos.RunBefore)
					}
					else {
						$mi.Start($AllAlgos.RunBefore)
					}
					$FastLoop = $false
				}
				Remove-Variable mi, miner
			}
			elseif ($run -and $activeMinerByType -and $activeMiner -and $Config.SwitchingResistance.Enabled -and
				$run.Miner.GetUniqueKey() -ne $activeMinerByType.Miner.GetUniqueKey() -and
				!($activeMinerByType.CurrentTime.Elapsed.TotalMinutes -gt $Config.SwitchingResistance.Timeout -or
				($run.Profit * 100 / $activeMiner.Profit - 100) -gt $Config.SwitchingResistance.Percent)) {
				$run.SwitchingResistance = $true
			}
			Remove-Variable run, activeMiner, activeMinerByType, activeMinersByType, allMinersByType, type
		}
		if ($global:API.Running) {
			$global:API.MinersRunning = $ActiveMiners.Values | Where-Object { $_.State -eq [eState]::Running } | Select-Object (Get-FormatActiveMinersWeb) | ConvertTo-Html -Fragment
		}
	}
	
	$Statistics.Write([Config]::StatsLocation)

	if (!$FastLoop) {
		$Summary.LoopTime.Reset()
		$Summary.LoopTime.Start()
	}

	Clear-Host
	Out-Header

	$verbose = $Config.Verbose -as [eVerbose]

	if ($verbose -eq [eVerbose]::Full) {
		Out-PoolInfo
	}
	
	$mult = if ($verbose -eq [eVerbose]::Normal) { 0.65 } else { 0.80 }
	$alg = [hashtable]::new()
	$AllMiners | Where-Object {
		$uniq =  $_.Miner.GetUniqueKey()
		$type = $_.Miner.Type
		if (!$alg[$type]) { $alg[$type] = [Collections.ArrayList]::new() }
		$_.Speed -eq 0 -or
			$verbose -eq [eVerbose]::Full -or
				($ActiveMiners.Values | Where-Object { $_.State -ne [eState]::Stopped -and $_.Miner.GetUniqueKey() -eq $uniq } | Select-Object -First 1) -or
					($_.Profit -ge (($AllMiners | Where-Object { $_.Miner.Type -eq $type } | Select-Object -First 1).Profit * $mult) -and
						$alg[$type] -notcontains "$($_.Miner.Algorithm)$($_.Miner.DualAlgorithm)")
		$ivar = $alg[$type].Add("$($_.Miner.Algorithm)$($_.Miner.DualAlgorithm)")
		Remove-Variable ivar, type, uniq
	} |
	Format-Table (Get-FormatMiners) -GroupBy @{ Label="Type"; Expression = { $_.Miner.Type } } | Out-Host
	Write-Host "+ Running, - No Hash, ! Failed, % Switching Resistance, * Specified Coin"
	Write-Host
	Remove-Variable alg, mult

	# display active miners
	$ActiveMiners.Values | Where-Object { $verbose -ne [eVerbose]::Minimal } |
		Sort-Object { [int]($_.State -as [eState]), [SummaryInfo]::Elapsed($_.TotalTime.Elapsed) } |
			Format-Table (Get-FormatActiveMiners) -GroupBy State -Wrap | Out-Host

	if ($Config.ShowBalance) {
		Out-PoolBalance ($verbose -eq [eVerbose]::Minimal)
	}
	Out-Footer
	if ($DownloadMiners.Length -gt 0) {
		Write-Host "Download $($DownloadMiners.Length) miner(s) ... " -ForegroundColor Yellow
	}
	if ($global:HasConfirm) {
		Write-Host "Please observe while the benchmarks are running ..." -ForegroundColor Red
	}

	Remove-Variable verbose

	do {
		$FastLoop = $false

		$start = [Diagnostics.Stopwatch]::new()
		$start.Start()
		do {
			Start-Sleep -Milliseconds ([Config]::SmallTimeout)
			while ([Console]::KeyAvailable -eq $true) {
				[ConsoleKeyInfo] $key = [Console]::ReadKey($true)
				if ($key.Key -eq [ConsoleKey]::V) {
					$items = [enum]::GetValues([eVerbose])
					$index = [array]::IndexOf($items, $Config.Verbose -as [eVerbose]) + 1
					$Config.Verbose = if ($items.Length -eq $index) { $items[0] } else { $items[$index] }
					Remove-Variable index, items
					Write-Host "Verbose level changed to $($Config.Verbose)." -ForegroundColor Green
					Start-Sleep -Milliseconds ([Config]::SmallTimeout * 2)
					$FastLoop = $true
				}
				elseif (($key.Modifiers -match [ConsoleModifiers]::Alt -or $key.Modifiers -match [ConsoleModifiers]::Control) -and
					($key.Key -eq [ConsoleKey]::C -or $key.Key -eq [ConsoleKey]::E -or $key.Key -eq [ConsoleKey]::Q -or $key.Key -eq [ConsoleKey]::X)) {
					$exit = $true
				}
				elseif ($key.Key -eq [ConsoleKey]::M) {
					Clear-OldMiners ($ActiveMiners.Values | Where-Object { $_.State -eq [eState]::Running } | ForEach-Object { $_.Miner.Name })
				}
				elseif ($key.Key -eq [ConsoleKey]::Y -and $global:HasConfirm -eq $false -and $global:NeedConfirm -eq $true) {
					Write-Host "Thanks. " -ForegroundColor Green -NoNewline
					Write-Host "Please observe while the benchmarks are running ..." -ForegroundColor Red
					Start-Sleep -Milliseconds ([Config]::SmallTimeout * 2)
					$global:HasConfirm = $true
					$FastLoop = $true
				}
				Remove-Variable key
			}
		} while ($start.Elapsed.TotalSeconds -lt $Config.CheckTimeout -and !$exit -and !$FastLoop)
		Remove-Variable start

		# if needed - exit
		if ($exit -eq $true) {
			Write-Host "Exiting ..." -ForegroundColor Green
			if ($global:API.Running) {
				Write-Host "Stoping API server ..." -ForegroundColor Green
				Stop-ApiServer
			}
			$ActiveMiners.Values | Where-Object { $_.State -eq [eState]::Running } | ForEach-Object {
				$_.Stop($AllAlgos.RunAfter)
			}
			exit
		}

		if (!$FastLoop) {
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
					$speed = $_.GetSpeed($false)
					if (($_.CurrentTime.Elapsed.TotalSeconds -ge $_.Miner.BenchmarkSeconds -and $speed -gt 0) -or
						($_.CurrentTime.Elapsed.TotalSeconds -ge ($_.Miner.BenchmarkSeconds * 2) -and $speed -eq 0)) {
						$FastLoop = $true
					}
					Remove-Variable speed
				}
			}
		}
		if ($global:API.Running) {
			$global:API.MinersRunning = $ActiveMiners.Values | Where-Object { $_.State -eq [eState]::Running } | Select-Object (Get-FormatActiveMinersWeb) | ConvertTo-Html -Fragment
			$global:API.Info = $Summary | Select-Object ($Summary.Columns()) | ConvertTo-Html -Fragment
		}
	} while ($Config.LoopTimeout -gt $Summary.LoopTime.Elapsed.TotalSeconds -and !$FastLoop)

	# if timeout reached - normal loop
	if ($Config.LoopTimeout -le $Summary.LoopTime.Elapsed.TotalSeconds) {
		$FastLoop = $false
	}

	if (!$FastLoop) {
		Remove-Variable AllPools, AllMiners
		[GC]::Collect()
		$Summary.Loop++
	}
}