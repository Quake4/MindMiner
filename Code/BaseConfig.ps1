<#
MindMiner  Copyright (C) 2017-2022  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

# read/write/store base confirguration
class BaseConfig {
	static [string] $Filename = ".config.txt"

	# save config file
	[void] Save([string] $fn) {
		$this | ConvertTo-Json -Depth 10 | Out-File -FilePath $fn -Force
	}

	# check exists file and really parsed
	static [bool] Exists([string] $fn) {
		try {
			$hash = [BaseConfig]::Read($fn)
			if ($hash -is [hashtable] -and $hash.Count -gt 0) {
				return $true
			}
		}
		catch { }
		return $false
	}

	static [void] Save([string] $fn, [hashtable] $hash) {
		$hash | ConvertTo-Json | Out-File -FilePath $fn -Force
	}

	# read json config
	static [hashtable] Read([string] $fn) {
		$temp = Get-Content -Path $fn | ConvertFrom-Json

		if ($temp) {
			$hash = @{}
			$temp | Get-Member -MemberType NoteProperty | ForEach-Object { $hash.Add($_.Name, $temp."$($_.Name)") }
			if ($hash.Count -gt 0) {
				return $hash
			}
		}

		return $null
	}

	# read or create config
	static [hashtable] ReadOrCreate([string] $fn, [hashtable] $hash) {
		try {
			$temp = Get-Content -Path $fn | ConvertFrom-Json
		}
		catch {
			$temp = $null
			# if exists rename to bak
			if (Test-Path $fn) {
				Remove-Item "$fn.bak" -Force | Out-Null
				Rename-Item $fn "$fn.bak" -Force | Out-Null
			}
		}

		if ($temp) {
			$hash = @{}
			$temp | Get-Member -MemberType NoteProperty | ForEach-Object { $hash.Add($_.Name, $temp."$($_.Name)") }
			return $hash
		}
		else {
			$hash | ConvertTo-Json -Depth 10 | Out-File -FilePath $fn -Force
			return $hash
		}
	}

	<# read or create config
	static [Object[]] ReadOrCreate([string] $fn, [Object[]] $array) {
		try {
			$temp = Get-Content -Path $fn | ConvertFrom-Json
		}
		catch {
			$temp = $null
		}

		if ($temp) {
			return $temp
		}
		else {
			$array | ConvertTo-Json -Depth 10 | Out-File -FilePath $fn -Force
			return $array
		}
	}
	#>
}