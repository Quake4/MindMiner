<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4/Quake3
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

class SummaryInfo {
	[int] $Loop
	[Diagnostics.Stopwatch] $TotalTime
	[Diagnostics.Stopwatch] $LoopTime
	[Diagnostics.Stopwatch] $FeeTime
	[Diagnostics.Stopwatch] $RateTime
	[timespan] $RateTimeout
	
	SummaryInfo([timespan] $minutes) {
		$this.Loop = 1
		$this.TotalTime = [Diagnostics.Stopwatch]::new()
		$this.LoopTime = [Diagnostics.Stopwatch]::new()
		$this.FeeTime = [Diagnostics.Stopwatch]::new()
		$this.RateTime = [Diagnostics.Stopwatch]::new()
		$this.RateTimeout = $minutes
	}

	[string] ToString() {
		$elapsed = [SummaryInfo]::Elapsed($this.TotalTime.Elapsed)
		$nl = [Environment]::NewLine
		return "" +
			("       Loop: {0,$($elapsed.Length):N0}" -f $this.Loop) + $nl +
			("   Run Time: {0,$($elapsed.Length)}" -f $elapsed) + $nl +
			("  Rate Time: {0,$($elapsed.Length)}" -f [SummaryInfo]::Elapsed($this.RateTimeout - $this.RateTime.Elapsed)) + $nl +
			("   Fee Time: {0,$($elapsed.Length)} ({1:P1})" -f [SummaryInfo]::Elapsed($this.FeeTime.Elapsed),
				($this.FeeTime.Elapsed.TotalMilliseconds / $this.TotalTime.Elapsed.TotalMilliseconds)) + $nl +
			("   Used RAM: {0,$($elapsed.Length):N1} Mb" -f ([GC]::GetTotalMemory(0)/1mb))
	}

	static [string] Elapsed([TimeSpan] $ts) {
		$f = "{1:00}:{2:00}:{3:00}"
		if ($ts.Days) { $f = "{0:0} " + $f }
		return $f -f $ts.Days, $ts.Hours, $ts.Minutes, $ts.Seconds
	}
}