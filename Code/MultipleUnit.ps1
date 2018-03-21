<#
Multiple Unit Converter v1.1 by Quake4
https://github.com/Quake4/MultipleUnit
License GPL-3.0
#>

class MultipleUnit {
	static [hashtable] $Known = @{
		"" = 0
		"K" = 3
		"M" = 6
		"G" = 9
		"T" = 12
		"P" = 15
		"E" = 18
		"Z" = 21
		"Y" = 24
	}

	static [decimal] ToValueInvariant([string] $value, [string] $unit) {
		return [MultipleUnit]::IntToValue($value, $unit, $true)
	}

	static [decimal] ToValue([string] $value, [string] $unit) {
		return [MultipleUnit]::IntToValue($value, $unit, $false)
	}

	hidden static [decimal] IntToValue([string] $value, [string] $unit, [bool] $invariant) {
		$unit = $unit.ToUpperInvariant()
		if ([MultipleUnit]::Known.ContainsKey($unit)) {
			[decimal] $val = $null
			if (($invariant -eq $true -and [decimal]::TryParse($value, [Globalization.NumberStyles]::Number, [Globalization.CultureInfo]::InvariantCulture, [ref] $val)) -or
				[decimal]::TryParse($value, [ref] $val)) {
				return $val * [Math]::Pow(10, [MultipleUnit]::Known."$unit")
			}
			throw [Exception]::new("Unknown value: " + $value)
		}
		throw [Exception]::new("Unknown multiple unit: " + $unit)
	}

	static [string] ToString([decimal] $value) {
		return [MultipleUnit]::ToString($value, "N")
	}

	static [string] ToString([decimal] $value, [string] $format) {
		return [MultipleUnit]::ToString($value, $format, [string]::Empty)
	}

	static [string] ToString([decimal] $value, [string] $format, [string] $suffux) {
		return [MultipleUnit]::ToString($value, $format, $suffux, $false)
	}

	static [string] ToStringInvariant([decimal] $value) {
		return [MultipleUnit]::ToStringInvariant($value, "N")
	}

	static [string] ToStringInvariant([decimal] $value, [string] $format) {
		return [MultipleUnit]::ToStringInvariant($value, $format, [string]::Empty)
	}

	static [string] ToStringInvariant([decimal] $value, [string] $format, [string] $suffux) {
		return [MultipleUnit]::ToString($value, $format, $suffux, $true)
	}

	static [string] ToString([decimal] $value, [string] $format, [string] $suffux, [bool] $invariant) {
		$measure = [MultipleUnit]::Measure($value)
		$unitsuffix = [MultipleUnit]::UnitByMeasure($measure) + $suffux

		$value /= [Math]::Pow(10, $measure)

		if ($invariant) {
			$result = $value.ToString($format, [Globalization.CultureInfo]::InvariantCulture)
		}
		else {
			$result = $value.ToString($format)
		}
		if ([string]::IsNullOrWhiteSpace($unitsuffix)) {
			return $result
		}
		return "$result $unitsuffix"
	}

	static [int] Measure([decimal] $value) {
		$prev = 0
		[MultipleUnit]::Known.Values | Sort-Object | ForEach-Object {
			if ([Math]::Abs($value / [Math]::Pow(10, $_)) -lt 1) {
				return $prev
			}
			$prev = $_
		}
		return $prev
	}

	static [string] UnitByMeasure([int] $measure) {
		$result = [string]::Empty
		[MultipleUnit]::Known.GetEnumerator() | ForEach-Object {
			if ($_.Value -eq $measure) {
				$result = $_.Key
			}
		}
		return $result
	}
}
