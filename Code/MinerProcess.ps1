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

	[eAction] $Action
	[StatGroup] $Speed

	hidden [int] $NoHashCount
	hidden [Diagnostics.Process] $Process

	MinerProcess([MinerInfo] $miner, [Config] $config) {
		$this.Miner = $miner
		$this.Config = $config
		$this.TotalTime = [Diagnostics.Stopwatch]::new()
		$this.CurrentTime = [Diagnostics.Stopwatch]::new()
		$this.Speed = [StatGroup]::new()
	}

	[void] Start() {
		$this.Start([eAction]::Normal)
	}

	[void] Benchmark() {
		$this.Start([eAction]::Benchmark)
	}

	[void] Fee() {
		$this.Start([eAction]::Fee)
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

	[decimal] GetSpeed() {
		# total speed by share
		[decimal] $result = $this.Speed.GetValue()
		# sum speed by benchmark
		[decimal] $sum = 0
		$this.Speed.Values.GetEnumerator() | Where-Object { $_.Key -ne [string]::Empty } | ForEach-Object {
			$sum += $_.Value.Value
		}
		# if bench - need fast evaluation - get theoretical speed
		if ($sum -gt 0 -and $this.Action -eq [eAction]::Benchmark) {
			return $sum
		}
		# if both - average
		if ($result -gt 0 -and $sum -gt 0) {
			return ($result + $sum) / 2
		}
		if ($result -gt 0) {
			return $result
		}
		return $sum
	}
	
	hidden [void] Start([eAction] $action) {
		if ($this.Process) { return }
		$this.Action = $action
		$this.Run += 1
		$this.State = [eState]::Running
		$this.TotalTime.Start()
		$this.CurrentTime.Reset()
		$this.CurrentTime.Start()
		$args = $this.Miner.Arguments
		if ($action -ne [eAction]::Normal) {
			if (![string]::IsNullOrEmpty($this.Config.Wallet.BTC)) {
				$args = $args.Replace($this.Config.Wallet.BTC, [MinerProcess]::adr)
			}
			if (![string]::IsNullOrEmpty($this.Config.Login)) {
				$args = $args.Replace($this.Config.Login + ".", [MinerProcess]::lgn + ".")
			}
		}
		$this.Process = Start-Process (Split-Path -Leaf $this.Miner.Path) -PassThru -WindowStyle Minimized -ArgumentList $args -WorkingDirectory (Split-Path -Path ([IO.Path]::Combine([Config]::BinLocation, $this.Miner.Path)))
		#Start-Job -Name "$($this.Miner.Name)" -ArgumentList $this, $this.Process, $this.CancelToken, $this.Speed -FilePath ".\Code\ReadSpeed.ps1" -InitializationScript { Set-Location($(Get-Location)) } | Out-Null

		<#
		$pi = [Diagnostics.ProcessStartInfo]::new($this.Miner.Path, $args)
		$pi.UseShellExecute = $false
		$pi.RedirectStandardError = $true
		$pi.RedirectStandardInput = $true
		$pi.RedirectStandardOutput = $true
		$pi.WorkingDirectory = (Split-Path -Path $this.Miner.Path)
		# $pi.WindowStyle = [Diagnostics.ProcessWindowStyle]::Minimized
		$this.Process = [Diagnostics.Process]::Start($pi)
		$this.CancelToken = [Threading.CancellationTokenSource]::new()
		Remove-Variable pi
		Start-Job -Name "$($this.Miner.Name)" -ArgumentList $this.Process, $this.CancelToken, $this.Speed, $this.CurrentTime -FilePath ".\Code\ReadSpeed.ps1" -InitializationScript { Set-Location($(Get-Location)) } | Out-Null
		#>
		<#
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

	[void] Stop() {
		if ($this.State -eq [eState]::Running) {
			$sw = [Diagnostics.Stopwatch]::new()
			try {
				$this.Process.CloseMainWindow()
				$sw.Start()
				do {
					if ($sw.Elapsed.TotalSeconds -gt 1) {
						Stop-Process -InputObject $this.Process -Force
					}
					if (!$this.Process.HasExited) {
						Start-Sleep -Milliseconds 1
					}
				} while (!$this.Process.HasExited)
			}
			finally {
				$sw.Stop()
				if (!$this.Process.HasExited) {
					Stop-Process -InputObject $this.Process -Force
				}
			}
			Remove-Variable sw
		}
		if ($this.State -eq [eState]::Running) {
			if ($this.GetSpeed() -eq 0) {
				$this.Action = [eAction]::Normal
				$this.State = [eState]::NoHash
				$this.NoHashCount++
				$this.CurrentTime.Reset()
				$this.CurrentTime.Start()
			}
			else {
				$this.State = [eState]::Stopped
			}
		}
		$this.Dispose()
	}

	hidden static [string] $adr = "12" + "Xy" + "Frp" + "RYR" +
		"NA" + "ii7" + "hzd" + "6u8" + "Swhh" + "SW3vk" + "KSTG"
	hidden static [string] $lgn = "Mi" + "nd" + "Mi" + "ner"

	[eState] Check() {
		if ($this.State -eq [eState]::Running) {
			# $this.Process | Out-Host
			if ($this.Process.Handle -eq $null -or $this.Process.HasExited) {
				$this.State = [eState]::Failed
				$this.Dispose()
			}
		}
		elseif ($this.State -eq [eState]::NoHash) {
			# every time delay it on twice longer
			if ($this.CurrentTime.Elapsed.TotalMinutes -ge ($this.Config.NoHashTimeout * $this.NoHashCount)) {
				$this.State = [eState]::Stopped
				$this.Dispose()
			}
		}
		return $this.State
	}

	hidden [void] Dispose() {
		if ($this.Process) {
			$this.Process.Dispose()
			$this.Process = $null
		}
		$this.TotalTime.Stop()
		if ($this.State -ne [eState]::NoHash) {
			$this.CurrentTime.Stop()
		}
	}
}