<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\MinerInfo.ps1
. .\Code\Config.ps1
. .\Code\StatInfo.ps1
. .\Code\MultipleUnit.ps1
. .\Code\MinerProcess.ps1

function Get-Speed() {
	param(
		[Parameter(Mandatory = $true)]
		[MinerProcess[]] $MinerProcess
	)

	# read speed only Running and time reach bench / 2
	$MinerProcess | Where-Object { $_.State -eq [eState]::Running -and 
		$_.CurrentTime.Elapsed.TotalSeconds -ge [Math]::Max($_.Miner.BenchmarkSeconds / 2, $_.Miner.BenchmarkSeconds - $_.Config.CheckTimeout * 2) } | ForEach-Object {
		$MP = $_
		$Server = "localhost"
		$Port = $_.Miner.Port
		$AVESpeed = "{0} sec" -f [Math]::Min([Convert]::ToInt32($MP.CurrentTime.Elapsed.TotalSeconds), $MP.Config.AverageCurrentHashSpeed)

#		Write-Host "Read $($MP.Miner.API) ..."
		
		switch ($MP.Miner.API.ToLower()) {
			"cpuminer" {
				@("summary", "threads") | ForEach-Object {
					try {
						$Client =[Net.Sockets.TcpClient]::new($Server, $Port)
						$Stream = $Client.GetStream()
						$Writer = [IO.StreamWriter]::new($Stream)
						$Reader = [IO.StreamReader]::new($Stream)

						$Writer.WriteLine($_)
						$Writer.Flush()
						$result = $Reader.ReadLine()
						if (![string]::IsNullOrWhiteSpace($result)) {
							# Write-Host $result
							$key = [string]::Empty
							[decimal] $speed = 0 # if var not initialized - this outputed to console
							if ($_ -eq "threads") {
								$result.Split(@("|","CPU=",";","KHS="), [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {
									if ([string]::IsNullOrWhiteSpace($key)) {
										$key = $_
									}
									else {
										$speed = [MultipleUnit]::ToValue($_, "K")
										#Write-Host "th $key $speed"
										if (($speed -ge 0 -and $MP.Action -eq [eAction]::Normal) -or ($speed -gt 0 -and $MP.Action -ne [eAction]::Normal)) {
											$speed = $MP.Speed.SetValue($key, $speed, $AVESpeed)
										}
										$key = [string]::Empty
									}
								}
							}
							else {
								$result.Split(@('|',';','='), [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {
									if ([string]::Equals($_, "KHS", [System.StringComparison]::InvariantCultureIgnoreCase)) {
										$key = $_
									}
									elseif (![string]::IsNullOrWhiteSpace($key)) {
										$speed = [MultipleUnit]::ToValue($_, "K")
										#Write-Host "sum $speed"
										if (($speed -ge 0 -and $MP.Action -eq [eAction]::Normal) -or ($speed -gt 0 -and $MP.Action -ne [eAction]::Normal)) {
											$speed = $MP.Speed.SetValue([string]::Empty, $speed, $AVESpeed)
										}
										$key = [string]::Empty
									}
								}
							}
							Remove-Variable speed, key
						}
						Remove-Variable result
					}
					catch {
						Write-Host "Get-Speed $($MP.Miner.API) error: $_" -ForegroundColor Red
					}
					finally {
						if ($Reader) { $Reader.Dispose() }
						if ($Writer) { $Writer.Dispose() }
						if ($Stream) { $Stream.Dispose() }
						if ($Client) { $Client.Dispose() }
					}
				}
			}

			"xmr-stak-cpu" {
				try {
					$Client = [Net.WebClient]::new()
					$result = $Client.DownloadString("http://$Server`:$Port/h")
					if (![string]::IsNullOrWhiteSpace($result)) {
						$totals = "Totals:"
						# find Totals:
						$from = $result.IndexOf($totals)
						if ($from -gt -1) {
							# exclude Totals:
							$from += $totals.Length;
							# find end line
							$end = $result.IndexOf("</tr>", $from)
							if ($end -gt -1) {
								$result = $result.Substring($from, $end - $from)
								# find '60s' or '2.5s' speed from results (2.5s 60s 15m H/s)
								[decimal] $speed = 0
								$result.Split(@(" ", "</th>", "<td>", "</td>"), [StringSplitOptions]::RemoveEmptyEntries) | Select-Object -First 2 | ForEach-Object {
									try {
										$speed = [MultipleUnit]::ToValue($_, [string]::Empty)
									}
									catch { }
								}
								if (($speed -ge 0 -and $MP.Action -eq [eAction]::Normal) -or ($speed -gt 0 -and $MP.Action -ne [eAction]::Normal)) {
									$speed = $MP.Speed.SetValue([string]::Empty, $speed, $AVESpeed)
								}
								Remove-Variable speed
							}
							Remove-Variable "end"
						}
						Remove-Variable "from", totals
					}
					Remove-Variable result
				}
				catch {
					Write-Host "Get-Speed $($MP.Miner.API) error: $_" -ForegroundColor Red
				}
				finally {
					if ($Client) { $Client.Dispose() }
				}
			}

			"ccminer" {
				@("summary", "threads"<# , "pool" #>) | ForEach-Object {
					try {
						$Client =[Net.Sockets.TcpClient]::new($Server, $Port)
						$Stream = $Client.GetStream()
						$Writer = [IO.StreamWriter]::new($Stream)
						$Reader = [IO.StreamReader]::new($Stream)

						$Writer.WriteLine($_)
						$Writer.Flush()
						$result = $Reader.ReadLine()
						if (![string]::IsNullOrWhiteSpace($result)) {
							# Write-Host $result
							$key = [string]::Empty
							[decimal] $speed = 0 # if var not initialized - this outputed to console
							<#
							if ($_ -eq "pool") {
								Write-Host "pool: $result"
								# pool: POOL=europe.hub.miningpoolhub.com:20510;ALGO=neoscrypt;URL=stratum+tcp://europe.hub.miningpoolhub.com:20510;USER=1.Home;SOLV=0;ACC=0;REJ=0;STALE=0;H=1997109;JOB=287d;DIFF=2048.000000;BEST=0.000000;N2SZ=4;N2=0x01000000;PING=0;DISCO=0;WAIT=0;UPTIME=0;LAST=0|
							}
							#>
							if ($_ -eq "threads") {
								$result.Split(@("|",";"), [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {
									if ([string]::IsNullOrWhiteSpace($key) -and $_.StartsWith("GPU=")) {
										$key = $_
									}
									elseif (![string]::IsNullOrWhiteSpace($key) -and $_.StartsWith("KHS=")) {
										$speed = [MultipleUnit]::ToValue($_.Replace("KHS=", ""), "K")
										#Write-Host "th $key $speed"
										if (($speed -ge 0 -and $MP.Action -eq [eAction]::Normal) -or ($speed -gt 0 -and $MP.Action -ne [eAction]::Normal)) {
											$speed = $MP.Speed.SetValue($key, $speed, $AVESpeed)
										}
										$key = [string]::Empty
									}
								}
							}
							else {
								$result.Split(@('|',';','='), [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {
									if ([string]::Equals($_, "KHS", [System.StringComparison]::InvariantCultureIgnoreCase)) {
										$key = $_
									}
									elseif (![string]::IsNullOrWhiteSpace($key)) {
										$speed = [MultipleUnit]::ToValue($_, "K")
										#Write-Host "sum $speed"
										if (($speed -ge 0 -and $MP.Action -eq [eAction]::Normal) -or ($speed -gt 0 -and $MP.Action -ne [eAction]::Normal)) {
											$speed = $MP.Speed.SetValue([string]::Empty, $speed, $AVESpeed)
										}
										$key = [string]::Empty
									}
								}
							}
							Remove-Variable speed, key
						}
						Remove-Variable result
					}
					catch {
						Write-Host "Get-Speed $($MP.Miner.API) error: $_" -ForegroundColor Red
					}
					finally {
						if ($Reader) { $Reader.Dispose() }
						if ($Writer) { $Writer.Dispose() }
						if ($Stream) { $Stream.Dispose() }
						if ($Client) { $Client.Dispose() }
					}
				}
			}

			"ewbf" {
				try {
					$Client =[Net.Sockets.TcpClient]::new($Server, $Port)
					$Stream = $Client.GetStream()
					$Writer = [IO.StreamWriter]::new($Stream)
					$Reader = [IO.StreamReader]::new($Stream)

					$Writer.WriteLine("{`"id`":1, `"method`":`"getstat`"}")
					$Writer.Flush()
					$result = $Reader.ReadLine()
					if (![string]::IsNullOrWhiteSpace($result)) {
						# Write-Host $result
						$resjson = $result | ConvertFrom-Json
						if ($resjson) {
							$resjson.result | ForEach-Object {
								$speed = [MultipleUnit]::ToValue($_.speed_sps, [string]::Empty)
								# exclude miner fee 2%
								$speed = $MP.Speed.SetValue($_.gpuid, $speed * 0.98, $AVESpeed)
							}
						}
						Remove-Variable speed, resjson
					}
					Remove-Variable result
				}
				catch {
					Write-Host "Get-Speed $($MP.Miner.API) error: $_" -ForegroundColor Red
				}
				finally {
					if ($Reader) { $Reader.Dispose() }
					if ($Writer) { $Writer.Dispose() }
					if ($Stream) { $Stream.Dispose() }
					if ($Client) { $Client.Dispose() }
				}
			}

			"nheq" {
				try {
					$Client =[Net.Sockets.TcpClient]::new($Server, $Port)
					$Stream = $Client.GetStream()
					$Writer = [IO.StreamWriter]::new($Stream)
					$Reader = [IO.StreamReader]::new($Stream)

					$Writer.WriteLine("status")
					$Writer.Flush()
					$result = $Reader.ReadLine()
					Write-Host $result
					if (![string]::IsNullOrWhiteSpace($result)) {
						# Write-Host $result
						$resjson = $result | ConvertFrom-Json
						if ($resjson) {
							$resjson.result | ForEach-Object {
								$speed = [MultipleUnit]::ToValue($_.speed_sps, [string]::Empty)
								$speed = $MP.Speed.SetValue([string]::Empty, $speed, $AVESpeed)
							}
						}
						Remove-Variable speed, resjson
					}
					Remove-Variable result
				}
				catch {
					Write-Host "Get-Speed $($MP.Miner.API) error: $_" -ForegroundColor Red
				}
				finally {
					if ($Reader) { $Reader.Dispose() }
					if ($Writer) { $Writer.Dispose() }
					if ($Stream) { $Stream.Dispose() }
					if ($Client) { $Client.Dispose() }
				}
			}
			
			"bminer" {
				# https://bitcointalk.org/index.php?topic=2519271.60

			}
				
			Default {
				throw [Exception]::new("Uknown miner: $($MP.Miner.API)!")
			}
		}
		Remove-Variable AVESpeed, Port, Server, MP
	}
}