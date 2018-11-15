<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

class SummaryInfo {
	[int] $Loop
	[Diagnostics.Stopwatch] $TotalTime
	[Diagnostics.Stopwatch] $LoopTime
	[Diagnostics.Stopwatch] $FeeTime
	[Diagnostics.Stopwatch] $FeeCurTime
	[Diagnostics.Stopwatch] $RateTime
	[timespan] $RateTimeout

	SummaryInfo([timespan] $minutes) {
		$this.Loop = 1
		$this.TotalTime = [Diagnostics.Stopwatch]::new()
		$this.LoopTime = [Diagnostics.Stopwatch]::new()
		$this.FeeTime = [Diagnostics.Stopwatch]::new()
		$this.FeeCurTime = [Diagnostics.Stopwatch]::new()
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

	hidden [Collections.ArrayList] $clmns
	[Collections.ArrayList] Columns() {
		if (!$this.clmns) {
			$this.clmns = [Collections.ArrayList]::new()
			$this.clmns.AddRange(@(
				@{ Label="Loop"; Expression = { "{0:N0}" -f $_.Loop } }
				@{ Label="Run Time"; Expression = { [SummaryInfo]::Elapsed($_.TotalTime.Elapsed) } }
				@{ Label="Rate Time"; Expression = { [SummaryInfo]::Elapsed($_.RateTimeout - $_.RateTime.Elapsed) } }
				@{ Label="Fee Time"; Expression = { "{0} ({1:P1})" -f [SummaryInfo]::Elapsed($_.FeeTime.Elapsed), ($_.FeeTime.Elapsed.TotalMilliseconds / $_.TotalTime.Elapsed.TotalMilliseconds) } }
				@{ Label="Used RAM"; Expression = { "{0:N1} Mb" -f ([GC]::GetTotalMemory(0)/1mb) } }
			))
		}
		return $this.clmns
	}

	hidden [Collections.ArrayList] $clmnsapi
	[Collections.ArrayList] ColumnsApi() {
		if (!$this.clmnsapi) {
			$this.clmnsapi = [Collections.ArrayList]::new()
			$this.clmnsapi.AddRange(@(
				@{ Label="runtime"; Expression = { [decimal]::Round($_.TotalTime.Elapsed.TotalSeconds, 0) } }
				@{ Label="feetime"; Expression = { [decimal]::Round($_.FeeTime.Elapsed.TotalSeconds) } }
			))
		}
		return $this.clmnsapi
	}

	[void] FStart() {
		$this.FeeCurTime.Start()
		$this.FeeTime.Start()
	}

	[void] FStop() {
		$this.FeeCurTime.Reset()
		$this.FeeTime.Stop()
	}

	static [string] Elapsed([TimeSpan] $ts) {
		$f = "{1:00}:{2:00}:{3:00}"
		if ($ts.Days) { $f = "{0:0}." + $f }
		return $f -f $ts.Days, $ts.Hours, $ts.Minutes, $ts.Seconds
	}
}