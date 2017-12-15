<#
Human Interval Converter v1.2 by Quake4
https://github.com/Quake4/HumanInterval
License GPL-3.0
#>

class HumanInterval {
	static [hashtable] $KnownIntervals = @{
		"seconds" = "sec"
		"second" = "sec"
		"secs" = "sec"
		"sec" = "sec"
		"minutes" = "min"
		"minute" = "min"
		"mins" = "min"
		"min" = "min"
		"hours" = "hour"
		"hour" = "hour"
		"days" = "day"
		"day" = "day"
		"weeks" = "week"
		"week" = "week"
	}

	static [timespan] Parse([string] $interval) {
		$interval = $interval.ToLower()
		[HumanInterval]::KnownIntervals.Keys | Sort-Object -Descending | ForEach-Object {
			$interval = $interval.Replace($_, " " + [HumanInterval]::KnownIntervals."$_" + " ")
		}
		[int] $days = 0
		[int] $hours = 0
		[int] $minutes = 0
		[int] $seconds = 0

		[int] $val = 0

		$interval.Split(@(' ', ',', ';'), [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {
			switch ($_) {
				"week" { $days += $val * 7; $val = 0 }
				"day" { $days += $val; $val = 0 }
				"hour" { $hours += $val; $val = 0 }
				"min" { $minutes += $val; $val = 0 }
				"sec" { $seconds += $val; $val = 0 }
				default {
					if (![int]::TryParse($_, [ref] $val)) {
						throw [Exception]::new("Unknow interval: $interval")
					}
				}
			}
		}
		if ($days -eq 0 -and $hours -eq 0 -and $minutes -eq 0 -and $seconds -eq 0) {
			throw [Exception]::new("Unknow interval: $interval")
		}
		return New-TimeSpan -Days $days -Hours $hours -Minutes $minutes -Seconds $seconds
	}
}

function Get-Interval ([Parameter(Mandatory)] [string] $Interval) {
	[HumanInterval]::Parse($Interval)
} 
