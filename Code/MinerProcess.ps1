<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\MinerInfo.ps1
. .\Code\Config.ps1
. .\Code\StatInfo.ps1
. .\Code\MultipleUnit.ps1

enum eState {
	Stopped
	Failed
	NoHash
	Running
}

enum eAction {
	Normal
	Benchmark
	Fee
}

class MinerProcess {
	[string] $State
	[MinerInfo] $Miner
	[Diagnostics.Stopwatch] $TotalTime
	[Diagnostics.Stopwatch] $CurrentTime
	[int] $Run
	[Config] $Config
	[int] $ErrorAnswer

	[eAction] $Action
	[StatGroup] $Speed
	[StatGroup] $SpeedDual
	[StatInfo] $Power
	[Shares] $Shares

	hidden [int] $NoHashCount
	hidden [Diagnostics.Process] $Process

	MinerProcess([MinerInfo] $miner, [Config] $config) {
		$this.Miner = [MinerInfo]($miner | ConvertTo-Json | ConvertFrom-Json)
		$this.Config = $config
		$this.TotalTime = [Diagnostics.Stopwatch]::new()
		$this.CurrentTime = [Diagnostics.Stopwatch]::new()
		$this.Speed = [StatGroup]::new()
		$this.SpeedDual = [StatGroup]::new()
		$this.Shares = [Shares]::new()
	}

	[void] Start($runbefore) {
		$this.Start([eAction]::Normal, $runbefore)
	}

	[void] Benchmark([bool] $nbench, $runbefore) {
		$act = if ($nbench) { [eAction]::Fee } else { [eAction]::Benchmark }
		$this.Start($act, $runbefore)
	}

	[bool] CanFee() {
		return $this.Miner.Arguments.IndexOf($this.Config.Wallet.BTC) -gt 0
	}

	[void] SetSpeed([string] $key, [decimal] $speed, [string] $interval) {
		if (($speed -ge 0 -and $this.Action -eq [eAction]::Normal) -or ($speed -gt 0 -and $this.Action -ne [eAction]::Normal)) {
			$spd = $this.Speed.SetValue($key, $speed * (100 - $this.Miner.Fee) / 100, $interval)
			Remove-Variable spd
		}
	}

	[void] SetSpeedDual([string] $key, [decimal] $speed, [string] $interval) {
		if (($speed -ge 0 -and $this.Action -eq [eAction]::Normal) -or ($speed -gt 0 -and $this.Action -ne [eAction]::Normal)) {
			$spd = $this.SpeedDual.SetValue($key, $speed * (100 - $this.Miner.Fee) / 100, $interval)
			Remove-Variable spd
		}
	}

	[decimal] GetSpeed([bool] $dual = $false) {
		$spd = $this.Speed
		$shrs = $this.Shares.Get($this.Miner.BenchmarkSeconds * 2);
		if ($dual) { $spd = $this.SpeedDual; $shrs = 1 }
		# total speed by share
		[decimal] $result = $spd.GetValue()
		# sum speed by benchmark
		[decimal] $sum = 0
		$spd.Values.GetEnumerator() | Where-Object { $_.Key -ne [string]::Empty } | ForEach-Object {
			$sum += $_.Value.Value
		}
		# if bench - need fast evaluation - get theoretical speed
		if ($sum -gt 0 -and $this.Action -eq [eAction]::Benchmark) {
			return $sum * $shrs
		}
		# if both - average
		if ($result -gt 0 -and $sum -gt 0) {
			return ($result + $sum) / 2 * $shrs
		}
		if ($result -gt 0) {
			return $result * $shrs
		}
		return $sum * $shrs
	}

	[void] SetPower([decimal] $power) {
		if ($this.Power) {
			$tmp = $this.Power.SetValue($power, "$($this.Config.AverageCurrentHashSpeed) sec")
			Remove-Variable tmp
		}
		else {
			$this.Power = [StatInfo]::new($power)
		}
	}

	[decimal] GetPower() {
		return $this.Power.Value;
	}
	
	hidden [void] Start([eAction] $action, $runbefore) {
		if ($this.Process) { return }
		if ($runbefore -and ![string]::IsNullOrWhiteSpace($runbefore."$($this.Miner.Algorithm)")) {
			$this.Miner.RunBefore = $runbefore."$($this.Miner.Algorithm)"
		}
		$this.Action = $action
		$this.Run += 1
		$this.State = [eState]::Running
		$this.TotalTime.Start()
		$this.CurrentTime.Reset()
		$this.CurrentTime.Start()
		$argmnts = $this.Miner.Arguments
		if ($action -ne [eAction]::Normal -and $action -ne [eAction]::Benchmark) {
			$this.Config.Wallet | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
				if ($argmnts.Contains(($this.Config.Wallet.$_))) {
					$argmnts = $argmnts.Replace($this.Config.Wallet.$_, [MinerProcess]::adr)
					if (@("BTC", "NiceHash") -notcontains "$_") {
						$sign = [regex]::new("c=(?<sign>[A-Z0-9]+)(,|\s)?")
						$match = $sign.Match($argmnts)
						if ($match.Success) {
							$argmnts = $argmnts.Remove($match.Groups["sign"].Index, $match.Groups["sign"].Length)
							$argmnts = $argmnts.Insert($match.Groups["sign"].Index, "BTC")
						}
						Remove-Variable match, sign
					}
				}
			}
			if (![string]::IsNullOrEmpty($this.Config.Login)) {
				$argmnts = $argmnts.Replace($this.Config.Login + ".", [MinerProcess]::lgn + ".")
			}
			$argmnts = $argmnts -replace ",m=solo" -replace "%2Cm=solo" -replace "%2Cm%3Dsolo"
		}
		$this.RunCmd($this.Miner.RunBefore)
		$Dir = Split-Path -Path ([IO.Path]::Combine([Config]::BinLocation, $this.Miner.Path))
		#fix xmr-stack
		Remove-Item "$Dir\pools.txt" -Force -ErrorAction SilentlyContinue
		$this.Process = Start-Process (Split-Path -Leaf $this.Miner.Path) -PassThru -WindowStyle ($this.Config.MinerWindowStyle) -ArgumentList $argmnts -WorkingDirectory $Dir
		#Start-Job -Name "$($this.Miner.Name)" -ArgumentList $this, $this.Process, $this.CancelToken, $this.Speed -FilePath ".\Code\ReadSpeed.ps1" -InitializationScript { Set-Location($(Get-Location)) } | Out-Null

		# [powershell] $ps = [powershell]::Create()
		# $ps.AddScript("Set-Location('$([IO.Path]::Combine((Get-Location), $Dir))')")
		# $ps.AddScript(".\'$(Split-Path -Leaf $this.Miner.Path)' $argmnts 2>&1 | Write-Verbose -Verbose")
		# $handler = $ps.BeginInvoke()

		#Start-Job -Name "$($this.Miner.Name)" -ArgumentList $this, $this.Process, $this.CancelToken, $this.Speed -FilePath ".\Code\ReadSpeed.ps1" -InitializationScript { Set-Location($(Get-Location)) } | Out-Null

		<#
		$pi = [Diagnostics.ProcessStartInfo]::new([IO.Path]::Combine((Get-Location), $Dir, (Split-Path -Leaf $this.Miner.Path)), $argmnts)
		$pi.UseShellExecute = $false
		$pi.RedirectStandardError = $true
		$pi.RedirectStandardInput = $true
		$pi.RedirectStandardOutput = $true
		$pi.WorkingDirectory = [IO.Path]::Combine((Get-Location), $Dir)
		# $pi.WindowStyle = [Diagnostics.ProcessWindowStyle]::Minimized
		$this.Process = [Diagnostics.Process]::Start($pi)
		$this.CancelToken = [Threading.CancellationTokenSource]::new()
		Remove-Variable pi

		$err = $null
		do {
			$std = $this.Process.StandardOutput.ReadLineAsync()
			if (!$err) {
				$err = $this.Process.StandardError.ReadLineAsync()
			}
			do {
				if ($std.Wait(250, $this.CancelToken.Token)) {
					$line = $std.Result
					Write-Host $line -ForegroundColor Gray
					if ($line.Contains("/s")) {
						$key = [string]::Empty
						if ($line.Contains("#")) {
							$reg1 = [regex]::new("(\w+)\s?#\s?(\d+)")
							$key = $reg1.Match($line).Value
							Remove-Variable reg1
						}
						$reg = [regex]::new("\s(\d+|\d+\.\d+)\s*(\w+)(h|hash|sol|sols)\/s", "ignorecase").Match($line)
						$this.Speed.SetValue($key, [MultipleUnit]::ToValue($reg.Groups[1].Value, $reg.Groups[2].Value), "$($this.CurrentTime.Elapsed.TotalSeconds) sec")
						Remove-Variable key, reg
					}
					$std.Dispose()
				}
			} while (!$std.IsCompleted -and !$this.CancelToken.IsCancellationRequested)
			if ($err.IsCompleted) {
				$line = $std.Result
				Write-Host $line -ForegroundColor Red
				$err.Dispose()
				$err = $null
			}
		} while (!$this.CancelToken.IsCancellationRequested)
		#>
	}

	hidden [void] StopMiner($runafter) {
		if ($runafter -and ![string]::IsNullOrWhiteSpace($runafter."$($this.Miner.Algorithm)")) {
			$this.Miner.RunAfter = $runafter."$($this.Miner.Algorithm)"
		}
		if ($this.State -eq [eState]::Running -and $this.Process) {
			$stoped = $false
			$procid = $this.Process.Id
			do {
				try {
					try {
						$this.Process.CloseMainWindow()
					}
					catch { }
					$this.Process.WaitForExit($this.Config.CheckTimeout * 1000)
					# Wait-Process -InputObject $this.Process -Timeout ($this.Config.CheckTimeout)
					if (!$this.Process.HasExited -or (Get-Process -Id $procid -ErrorAction SilentlyContinue)) {
						Write-Host "Process $($this.Miner.Name) not exit for $($this.Config.CheckTimeout) sec. Kill it." -ForegroundColor Red
						$this.Process.Kill()
						# Stop-Process -InputObject $this.Process -Force
						$this.Process.WaitForExit($this.Config.CheckTimeout * 1000)
						# Wait-Process -InputObject $this.Process -Timeout ($this.Config.CheckTimeout)
						if (!$this.Process.HasExited -or (Get-Process -Id $procid -ErrorAction SilentlyContinue)) {
							throw [Exception]::new("Can't stop!")
						}
						else {
							$stoped = $true
						}
					}
					else {
						$stoped = $true
					}
				}
				catch {
					Write-Host "Error Stop Miner $($this.Miner.Name): $_" -ForegroundColor Red
				}
			} while (!$stoped)
			Remove-Variable procid, stoped
		}
	}

	[void] Stop($runafter) {
		$this.StopMiner($runafter)
		if ($this.State -eq [eState]::Running) {
			if ($this.GetSpeed($false) -eq 0) {
				$this.Action = [eAction]::Normal
				if ($global:HasConfirm -eq $true -or $this.CurrentTime.Elapsed.TotalSeconds -lt ($this.Miner.BenchmarkSeconds * 2)) {
					$this.State = [eState]::Stopped
				}
				else {
					$this.State = [eState]::NoHash
					$this.NoHashCount++
					$this.CurrentTime.Reset()
					$this.CurrentTime.Start()
				}
			}
			else {
				$this.State = [eState]::Stopped
			}
		}
		if ($this.Config.CoolDown -gt 0) {
			Write-Host "CoolDown on switch: $($this.Config.CoolDown) sec" -ForegroundColor Yellow
			Start-Sleep -Seconds $this.Config.CoolDown
		}
		$this.Dispose()
	}

	hidden static [string] $adr = "12" + "Xy" + "Frp" + "RYR" +
		"NA" + "ii7" + "hzd" + "6u8" + "Swhh" + "SW3vk" + "KSTG"
	hidden static [string] $lgn = "Mi" + "nd" + "Mi" + "ner"

	[eState] Check($runafter) {
		if ($this.State -eq [eState]::Running) {
			if ($this.Process.Handle -eq $null -or $this.Process.HasExited -or $this.ErrorAnswer -ge 10) {
				$this.StopMiner($runafter);
				$this.State = [eState]::Failed
				$this.Dispose()
			}
		}
		# reset nohash state (every time delay it on twice longer) or reset failed state
		elseif (
			($this.State -eq [eState]::NoHash -and $this.CurrentTime.Elapsed.TotalMinutes -ge ($this.Config.NoHashTimeout * $this.NoHashCount)) -or
			($this.State -eq [eState]::Failed -and $this.CurrentTime.Elapsed.TotalMinutes -ge ($this.Config.NoHashTimeout * $this.Config.LoopTimeout * 0.5))) {
			$this.ResetFailed();
		}
		return $this.State
	}

	[void] ResetFailed() {
		if ($this.State -eq [eState]::Failed) {
			$this.State = [eState]::Stopped;
			$this.ErrorAnswer = 0;
			$this.Dispose();
		}
	}

	hidden [void] RunCmd([string] $cmdline) {
		Start-Command ([Config]::RunLocation) $cmdline
	}

	hidden [void] Dispose() {
		if ($this.Process) {
			$this.RunCmd($this.Miner.RunAfter)
			$this.Process.Dispose()
			$this.Process = $null
		}
		$this.TotalTime.Stop()
		if ($this.State -ne [eState]::NoHash -and $this.State -ne [eState]::Failed) {
			$this.CurrentTime.Stop()
		}
	}
}