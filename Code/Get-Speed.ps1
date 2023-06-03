<#
MindMiner  Copyright (C) 2017-2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\MinerInfo.ps1
. .\Code\Config.ps1
. .\Code\StatInfo.ps1
. .\Code\MultipleUnit.ps1
. .\Code\MinerProcess.ps1

function Get-TCPCommand([Parameter(Mandatory)][MinerProcess] $MinerProcess, [Parameter(Mandatory)][string] $Server, [Parameter(Mandatory)][int] $Port,
	[string] $Command, [Parameter(Mandatory)][scriptblock] $Script, [bool] $ReadAll) {
	try {
		$Client =[Net.Sockets.TcpClient]::new($Server, $Port)
		$Client.ReceiveTimeout = $Client.SendTimeout = $MinerProcess.Config.CheckTimeout * 1000
		$Stream = $Client.GetStream()
		$Stream.ReadTimeout = $Stream.WriteTimeout = $MinerProcess.Config.CheckTimeout * 1000;
		$Writer = [IO.StreamWriter]::new($Stream)
		$Reader = [IO.StreamReader]::new($Stream)

		if (![string]::IsNullOrWhiteSpace($Command)) {
			# if ($MinerProcess.Miner.API.ToLower() -eq "dredge") { $Writer.Write($Command) } else { $Writer.WriteLine($Command) };
			$Writer.WriteLine($Command)
			$Writer.Flush()
		}
		if ($ReadAll) { $result = $Reader.ReadToEnd() } else { $result = $Reader.ReadLine() }
		if (![string]::IsNullOrWhiteSpace($result)) {
			$Script.Invoke($result)
		}
		else {
			$MinerProcess.ErrorAnswer++
		}
		Remove-Variable result
	}
	catch {
		Write-Host "Get-Speed $($MinerProcess.Miner.Name) error: $_" -ForegroundColor Red
		$MinerProcess.ErrorAnswer++
	}
	finally {
		if ($Reader) { $Reader.Dispose(); $Reader = $null }
		if ($Writer) { $Writer.Dispose(); $Writer = $null }
		if ($Stream) { $Stream.Dispose(); $Stream = $null }
		if ($Client) { $Client.Dispose(); $Client = $null }
	}
}

<#
function Get-Http ([Parameter(Mandatory)][MinerProcess] $MinerProcess, [Parameter(Mandatory)][string] $Url, [Parameter(Mandatory)][scriptblock] $Script) {
	try {
		$Request = Invoke-WebRequest $Url -UseBasicParsing -TimeoutSec ($MinerProcess.Config.CheckTimeout)
		if ($Request -and $Request.StatusCode -eq 200 -and ![string]::IsNullOrWhiteSpace($Request.Content)) {
			$Script.Invoke($Request.Content)
		}
		else {
			$MinerProcess.ErrorAnswer++
		}
	}
	catch {
		Write-Host "Get-Speed $($MinerProcess.Miner.Name) error: $_" -ForegroundColor Red
		$MinerProcess.ErrorAnswer++
	}
	finally {
		if ($Request -is [IDisposable]) { $Request.Dispose(); $Request = $null; }
	}
}
#>

function Get-HttpAsJson ([Parameter(Mandatory)][MinerProcess] $MinerProcess, [Parameter(Mandatory)][string] $Url, [Parameter(Mandatory)][scriptblock] $ScriptInt) {
	try {
		$Request = Invoke-RestMethod -Uri $Url -UseBasicParsing -TimeoutSec ($MinerProcess.Config.CheckTimeout)
		if ($Request -is [PSCustomObject] -or $Request -is [array]) {
			$ScriptInt.Invoke($Request)
		}
		else {
			$MinerProcess.ErrorAnswer++
		}
	}
	catch {
		Write-Host "Get-Speed $($MinerProcess.Miner.Name) error: $_" -ForegroundColor Red
		$MinerProcess.ErrorAnswer++
	}
	finally {
		if ($Request -is [IDisposable]) { $Request.Dispose(); $Request = $null; }
	}
}

function Get-Speed([Parameter(Mandatory = $true)] [MinerProcess[]] $MinerProcess) {
	# read speed only Running and time reach bench / 2
	$MinerProcess | Where-Object { $_.State -eq [eState]::Running -and 
		$_.CurrentTime.Elapsed.TotalSeconds -ge [Math]::Max($_.Miner.BenchmarkSeconds / 2, $_.Miner.BenchmarkSeconds - $_.Config.CheckTimeout * 2) } | ForEach-Object {
		$MP = $_
		$Server = "127.0.0.1"
		$Port = $_.Miner.Port
		$AVESpeed = "{0} sec" -f [Math]::Min([Convert]::ToInt32($MP.CurrentTime.Elapsed.TotalSeconds), $MP.Config.AverageCurrentHashSpeed)

		switch ($MP.Miner.API.ToLower()) {
			"cpuminer" {
				@("summary", "threads") | ForEach-Object {
					Get-TCPCommand $MP $Server $Port $_ {
						Param([string] $result)

						if ($_ -eq "threads") {
							$key = [string]::Empty
							$result.Split(@("|",";"), [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {
								if ([string]::IsNullOrWhiteSpace($key) -and $_.StartsWith("CPU=")) {
									$key = $_.Replace("CPU=", [string]::Empty)
								}
								elseif (![string]::IsNullOrWhiteSpace($key)) {
									$split = $_.Split(@("="))
									Set-SpeedStr $key $split[1] ($split[0].Replace("H/s", [string]::Empty).Replace("HS", [string]::Empty))
									$key = [string]::Empty
									Remove-Variable split
								}
							}
							Remove-Variable key
						}
						else {
							$obj = $result -split ';' | ConvertFrom-StringData
							Set-SpeedStr ([string]::Empty) ($obj.KHS) "K"
							$MP.Shares.AddAccepted($obj.ACC);
							$MP.Shares.AddRejected($obj.REJ);
							Remove-Variable obj
						}
					}
				}
			}

			{ $_ -eq "ccminer" -or $_ -eq "ccminer_woe" -or $_ -eq "dredge" } {
				$commands = if ($_ -eq "ccminer_woe") { @("summary") } else { @("summary", "threads"<# , "pool" #>) }
				$commands | ForEach-Object {
					Get-TCPCommand $MP $Server $Port $_ {
						Param([string] $result)

						<#
						if ($_ -eq "pool") {
							Write-Host "pool: $result"
							# pool: POOL=europe.hub.miningpoolhub.com:20510;ALGO=neoscrypt;URL=stratum+tcp://europe.hub.miningpoolhub.com:20510;USER=1.Home;SOLV=0;ACC=0;REJ=0;STALE=0;H=1997109;JOB=287d;DIFF=2048.000000;BEST=0.000000;N2SZ=4;N2=0x01000000;PING=0;DISCO=0;WAIT=0;UPTIME=0;LAST=0|
						}
						#>
						if ($_ -eq "threads" -and $MP.Miner.API.ToLower() -ne "ccminer_woe") {
							$key = [string]::Empty
							$result.Split(@("|",";"), [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {
								if ([string]::IsNullOrWhiteSpace($key) -and $_.StartsWith("GPU=")) {
									$key = $_.Replace("GPU=", [string]::Empty)
								}
								elseif (![string]::IsNullOrWhiteSpace($key) -and $_.StartsWith("KHS=")) {
									Set-SpeedStr $key ($_.Replace("KHS=", [string]::Empty)) "K"
									$key = [string]::Empty
								}
							}
							Remove-Variable key
						}
						elseif ($_ -eq "summary") {
							$obj = $result -split ';' | ConvertFrom-StringData
							Set-SpeedStr ([string]::Empty) ($obj.KHS) "K"
							$MP.Shares.AddAccepted($obj.ACC);
							$MP.Shares.AddRejected($obj.REJ);
							Remove-Variable obj
						}
					}
				}
			}

			"ewbf" {
				Get-TCPCommand $MP $Server $Port "{`"id`":1, `"method`":`"getstat`"}" {
					Param([string] $result)

					$resjson = $result | ConvertFrom-Json
					if ($resjson) {
						$acc = 0;
						$rej = 0;
						$resjson.result | ForEach-Object {
							Set-SpeedStr ($_.gpuid) ($_.speed_sps) ([string]::Empty)
							$acc += $_.accepted_shares;
							$rej += $_.rejected_shares;
						}
						$MP.Shares.AddAccepted($acc);
						$MP.Shares.AddRejected($rej);
					}
					else {
						$MP.ErrorAnswer++
					}
					Remove-Variable resjson
				}
			}

			"miniz" {
				Get-HttpAsJson $MP "http://$Server`:$Port/{`"id`":1, `"method`":`"getstat`"}" {
					Param([PSCustomObject] $resjson)

					$acc = 0;
					$rej = 0;
					$resjson.result | ForEach-Object {
						Set-SpeedStr ($_.gpuid) ($_.speed_sps) ([string]::Empty)
						$acc += $_.accepted_shares;
						$rej += $_.rejected_shares;
					}
					$MP.Shares.AddAccepted($acc);
					$MP.Shares.AddRejected($rej);
				}
			}

			{ $_ -eq "nheq" -or $_ -eq "nheq_verus" } {
				Get-TCPCommand $MP $Server $Port "status" {
					Param([string] $result)

					$resjson = $result | ConvertFrom-Json
					if ($resjson) {
						$unit = [string]::Empty
						$value = $resjson.result.speed_sps
						if ($MP.Miner.API.ToLower() -eq "nheq_verus" ) {
							$unit = "M"
							$value = $resjson.result.speed_ips
						}
						Set-SpeedStr ([string]::Empty) $value $unit
						if (($resjson.result.accepted_per_minute + $resjson.result.rejected_per_minute) -gt 0) {
							$MP.Shares.SetValue($resjson.result.accepted_per_minute / ($resjson.result.accepted_per_minute + $resjson.result.rejected_per_minute))
						}
						else {
							$MP.Shares.SetValue(0)
						}
						Remove-Variable value, unit
					}
					else {
						$MP.ErrorAnswer++
					}
					Remove-Variable resjson
				}
			}

			{ $_ -eq "sgminer" -or $_ -eq "teamred"} {
				# https://github.com/ckolivas/cgminer/blob/master/API-README
				Get-TCPCommand $MP $Server $Port "{`"command`":`"summary+devs`"}" {
					Param([string] $result)

					# fix error symbol at end
					while ($result[$result.Length - 1] -eq 0) {
						$result = $result.substring(0, $result.Length - 1)
					}
					$key = "KHS 5s"
					if ($MP.Miner.API.ToLower() -eq "teamred" ) { $key = "KHS 30s" }
					$resjson = $result | ConvertFrom-Json
					if ($resjson) {
						if ($resjson.devs[0].DEVS) {
							$resjson.devs[0].DEVS | ForEach-Object {
								Set-SpeedStr ($_.GPU) ($_.$key) "K"
							}
						}
						Set-SpeedStr ([string]::Empty) ($resjson.summary[0].SUMMARY.$key) "K"
						$MP.Shares.AddAccepted($resjson.summary[0].SUMMARY.Accepted);
						$MP.Shares.AddRejected($resjson.summary[0].SUMMARY.Rejected);
						# stale??? $resjson.summary[0].SUMMARY.Stale
					}
					else {
						$MP.ErrorAnswer++
					}
					Remove-Variable resjson
				}
			}

			{ $_ -eq "claymore" -or $_ -eq "claymoredual" } {
				Get-TCPCommand $MP $Server $Port "{`"id`":1,`"jsonrpc`":`"2.0`",`"method`":`"miner_getstat1`"}" {
					Param([string] $result)

					$resjson = $result | ConvertFrom-Json
					if ($resjson) {
						$measure = [string]::Empty
						if ($resjson.result[0].Contains("ETH") -or $resjson.result[0].Contains("NS") -or $resjson.result[0].Contains("ethminer") -or
							($resjson.result[0].Contains("PM") -and !$resjson.result[0].Contains("3.0c"))) { $measure = "K" }
						if (![string]::IsNullOrWhiteSpace($resjson.result[2])) {
							$item = $resjson.result[2].Split(@(';'), [StringSplitOptions]::RemoveEmptyEntries)
							Set-SpeedStr ([string]::Empty) ($item[0]) $measure
							$MP.Shares.AddAccepted($item[1]);
							$MP.Shares.AddRejected($item[2]);
							Remove-Variable item
						}
						if (![string]::IsNullOrWhiteSpace($resjson.result[3])) {
							$items = $resjson.result[3].Split(@(';'), [StringSplitOptions]::RemoveEmptyEntries)
							for ($i = 0; $i -lt $items.Length; $i++) {
								Set-SpeedStr "$i" ($items[$i]) $measure
							}
							Remove-Variable items
						}
						if ($MP.Miner.API.ToLower() -eq "claymoredual") {
							if (![string]::IsNullOrWhiteSpace($resjson.result[4])) {
								$item = $resjson.result[4].Split(@(';'), [StringSplitOptions]::RemoveEmptyEntries) | Select-Object -First 1
								Set-SpeedDualStr ([string]::Empty) $item $measure
								Remove-Variable item
							}
							if (![string]::IsNullOrWhiteSpace($resjson.result[3])) {
								$items = $resjson.result[5].Split(@(';'), [StringSplitOptions]::RemoveEmptyEntries)
								for ($i = 0; $i -lt $items.Length; $i++) {
									Set-SpeedDualStr "$i" ($items[$i]) $measure
								}
								Remove-Variable items
							}
						}
						Remove-Variable measure
					}
					else {
						$MP.ErrorAnswer++
					}
					Remove-Variable resjson
				}
			}

			"cast" {
				Get-HttpAsJson $MP "http://$Server`:$Port" {
					Param([PSCustomObject] $resjson)

					[decimal] $speed = 0 # if var not initialized - this outputed to console
					$resjson.devices | ForEach-Object {
						$speed = [MultipleUnit]::ToValueInvariant($_.hash_rate, [string]::Empty)
						Set-SpeedVal ($_.device) ($speed / 1000)
					}
					$speed = [MultipleUnit]::ToValueInvariant($resjson.total_hash_rate, [string]::Empty)
					Set-SpeedVal ([string]::Empty) ($speed / 1000)
					Remove-Variable speed

					$MP.Shares.AddAccepted($resjson.shares.num_accepted);
					$MP.Shares.AddRejected($resjson.shares.num_rejected);
				}
			}
			
			"bminer" {
				Get-HttpAsJson $MP "http://$Server`:$Port/api/status" {
					Param([PSCustomObject] $resjson)

					$resjson.miners | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
						Set-SpeedStr $_ ($resjson.miners."$_".solver.solution_rate) ([string]::Empty)
					}

					$MP.Shares.AddAccepted($resjson.stratum.accepted_shares);
					$MP.Shares.AddRejected($resjson.stratum.rejected_shares);
				}
			}

			"bminerdual" {
				Get-HttpAsJson $MP "http://$Server`:$Port/api/v1/status/solver" {
					Param([PSCustomObject] $resjson)

					$resjson.devices | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
						$id = "$_"
						$resjson.devices."$_".solvers | ForEach-Object {
							if ($_.algorithm -match "ethash") {
								Set-SpeedStr $id ($_.speed_info.hash_rate) ([string]::Empty)
							}
							else {
								Set-SpeedDualStr "$i" ($_.speed_info.hash_rate) ([string]::Empty)
							}
						}
						Remove-Variable id
					}
				}

				Get-HttpAsJson $MP "http://$Server`:$Port/api/v1/status/stratum" {
					Param([PSCustomObject] $resjson)

					$MP.Shares.AddAccepted($resjson.stratums.ethash.accepted_shares);
					$MP.Shares.AddRejected($resjson.stratums.ethash.rejected_shares);
				}
			}

			{ $_ -eq "xmrig" -or $_ -eq "xmrig2" -or $_ -eq "xmr-stak" } {
				$url = "http://$Server`:$Port";
				if ($_ -eq "xmr-stak") {
					$url += "/api.json";
				}
				elseif ($_ -eq "xmrig2") {
					$url += "/1/summary";
				}
				Get-HttpAsJson $MP $url {
					Param([PSCustomObject] $resjson)

					[decimal] $speed = 0 # if var not initialized - this outputed to console
					for ($i = 0; $i -lt $resjson.hashrate.threads.Length; $i++) {
						$speed = if ($resjson.hashrate.threads[$i][1] -gt 0) { $resjson.hashrate.threads[$i][1] } else { $resjson.hashrate.threads[$i][0] }
						Set-SpeedVal "$i" $speed
					}
					$speed = if ($resjson.hashrate.total[1] -gt 0) { $resjson.hashrate.total[1] } else { $resjson.hashrate.total[0] }
					Set-SpeedVal ([string]::Empty) $speed
					Remove-Variable speed

					$MP.Shares.AddTotal($resjson.results.shares_total);
					$MP.Shares.AddAccepted($resjson.results.shares_good);
				}
			}

			"lol2" {
				Get-HttpAsJson $MP "http://$Server`:$Port/summary" {
					Param([PSCustomObject] $resjson)

					if ($resjson.Num_Algorithms -gt 0) {
						$alg = $resjson.Algorithms[0];
						$factor = $alg.Performance_Factor
						$i = 0;
						$alg.Worker_Performance | ForEach-Object {
							Set-SpeedVal ($i++) ($_ * $factor)
						}
						Set-SpeedVal ([string]::Empty) ($alg.Total_Performance * $factor)
						$MP.Shares.AddAccepted($alg.Total_Accepted);
						$MP.Shares.AddRejected($alg.Total_Rejected);
						Remove-Variable alg, i, factor
					}
				}
			}

			"lolnew" {
				Get-HttpAsJson $MP "http://$Server`:$Port/summary" {
					Param([PSCustomObject] $resjson)

					$unit = $resjson.Session.Performance_Unit -replace "h/s" -replace "sol/s" -replace "g/s";
					$resjson.GPUs | ForEach-Object {
						Set-SpeedStr ($_.Index) ($_.Performance) $unit
					}
					Set-SpeedStr ([string]::Empty) ($resjson.Session.Performance_Summary) $unit
					$MP.Shares.AddTotal($resjson.Session.Submitted);
					$MP.Shares.AddAccepted($resjson.Session.Accepted);
					Remove-Variable unit
				}
			}

			"gminer" {
				Get-HttpAsJson $MP "http://$Server`:$Port/api/v1/status" {
					Param([PSCustomObject] $resjson)

					$resjson.miner.devices | ForEach-Object {
						Set-SpeedStr ($_.id) ($_.hashrate) ([string]::Empty)
					}
					Set-SpeedStr ([string]::Empty) ($resjson.miner.total_hashrate) ([string]::Empty)
					$MP.Shares.AddAccepted($resjson.stratum.accepted_shares);
					$MP.Shares.AddRejected($resjson.stratum.rejected_shares);

					if ($MP.Miner.IsDual()) {
						Set-SpeedDualVal ([string]::Empty) ($resjson.miner.total_hashrate2)
						$MP.SharesDual.AddAccepted($resjson.stratum.accepted_shares2);
						$MP.SharesDual.AddRejected($resjson.stratum.rejected_shares2);
					}
				}
			}

			"nbminer" {
				Get-HttpAsJson $MP "http://$Server`:$Port/api/v1/status" {
					Param([PSCustomObject] $resjson)
					
					$resjson.miner.devices | ForEach-Object {
						Set-SpeedStr ($_.id) ($_.hashrate_raw) ([string]::Empty)
					}
					Set-SpeedStr ([string]::Empty) ($resjson.miner.total_hashrate_raw) ([string]::Empty)
					$MP.Shares.AddAccepted($resjson.stratum.accepted_shares);
					$MP.Shares.AddRejected($resjson.stratum.rejected_shares);
				}
			}

			"srbm" {
				Get-HttpAsJson $MP "http://$Server`:$Port" {
					Param([PSCustomObject] $resjson)

					Set-SpeedVal ([string]::Empty) $(if ($resjson.hashrate_total_1min -gt 0) { $resjson.hashrate_total_1min } else { $resjson.hashrate_total_now })
					$MP.Shares.AddAccepted($resjson.shares.accepted);
					$MP.Shares.AddRejected($resjson.shares.rejected);
				}
			}

			"srbm2" {
				Get-HttpAsJson $MP "http://$Server`:$Port" {
					Param([PSCustomObject] $resjson)

					$alg = $resjson.algorithms[0];
					if ($alg.hashrate."1min" -gt 0) {
						Set-SpeedVal ([string]::Empty) ($alg.hashrate."1min")
					} # $alg.hashrate.now
					$MP.Shares.AddAccepted($alg.shares.accepted);
					$MP.Shares.AddRejected($alg.shares.rejected);

					if ($MP.Miner.IsDual()) {
						$alg = $resjson.algorithms[1];
						if ($alg.hashrate."1min" -gt 0) {
							Set-SpeedDualVal ([string]::Empty) ($alg.hashrate."1min")
						}
						$MP.SharesDual.AddAccepted($alg.shares.accepted);
						$MP.SharesDual.AddRejected($alg.shares.rejected);
					}

					Remove-Variable alg
				}
			}

			"srbm2dual" {
				Get-HttpAsJson $MP "http://$Server`:$Port" {
					Param([PSCustomObject] $resjson)

					$alg = $resjson.algorithms[0];
					if ($alg.hashrate."1min" -gt 0) {
						Set-SpeedVal ([string]::Empty) ($alg.hashrate."1min")
					}
					$MP.Shares.AddAccepted($alg.shares.accepted);
					$MP.Shares.AddRejected($alg.shares.rejected);
					
					$alg = $resjson.algorithms[1];
					if ($alg.hashrate."1min" -gt 0) {
						Set-SpeedDualVal ([string]::Empty) ($alg.hashrate."1min")
					}
					$MP.SharesDual.AddAccepted($alg.shares.accepted);
					$MP.SharesDual.AddRejected($alg.shares.rejected);

					Remove-Variable alg
				}
			}

			"trex" {
				Get-HttpAsJson $MP "http://$Server`:$Port/summary" {
					Param([PSCustomObject] $resjson)
					<#
					$resjson.gpus | ForEach-Object {
						Set-SpeedVal ($_.device_id) ($_.hashrate_minute);
					}
					#>
					Set-SpeedVal ([string]::Empty) ($resjson.hashrate);
					$MP.Shares.AddAccepted($resjson.accepted_count);
					$MP.Shares.AddRejected($resjson.rejected_count);
				}
			}

			"rigel" {
				Get-HttpAsJson $MP "http://$Server`:$Port" {
					Param([PSCustomObject] $resjson)
					
					Set-SpeedVal ([string]::Empty) ($resjson.hashrate."$($resjson.algorithm)");
					$MP.Shares.AddAccepted($resjson.solution_stat."$($resjson.algorithm)".accepted);
					$MP.Shares.AddRejected($resjson.solution_stat."$($resjson.algorithm)".rejected);
				}
			}

			"bzminer" {
				Get-HttpAsJson $MP "http://$Server`:$Port/status" {
					Param([PSCustomObject] $resjson)

					Set-SpeedVal ([string]::Empty) ($resjson.pools[0].hashrate);
					$MP.Shares.AddAccepted($resjson.pools[0].valid_solutions);
					$MP.Shares.AddRejected($resjson.pools[0].rejected_solutions);
				}
			}

			Default {
				throw [Exception]::new("Get-Speed: Unknown miner $($MP.Miner.API)!")
			}
		}
		Remove-Variable AVESpeed, Port, Server, MP
	}
}

function Set-SpeedStr ([string] $Key, [string] $Value, [string] $Unit) {
	[decimal] $speed = [MultipleUnit]::ToValueInvariant($Value, $Unit)
	Set-SpeedVal $Key $speed
	Remove-Variable speed
}

function Set-SpeedVal ([string] $Key, [decimal] $Value) {
	if ($Value -lt [Config]::MinSpeed) {
		$Value = 0
	}
	$MP.SetSpeed($Key, $Value, $AVESpeed)
}

function Set-SpeedStrMultiplier ([string] $Key, [string] $Value, [decimal] $Multiplier) {
	[decimal] $speed = [MultipleUnit]::ToValueInvariant($Value, [string]::Empty) * $Multiplier
	Set-SpeedVal $Key $speed
	Remove-Variable speed
}

function Set-SpeedDualStr ([string] $Key, [string] $Value, [string] $Unit) {
	[decimal] $speed = [MultipleUnit]::ToValueInvariant($Value, $Unit)
	Set-SpeedDualVal $Key $speed
	Remove-Variable speed
}

function Set-SpeedDualVal ([string] $Key, [decimal] $Value) {
	if ($Value -lt [Config]::MinSpeed) {
		$Value = 0
	}
	$MP.SetSpeedDual($Key, $Value, $AVESpeed)
}