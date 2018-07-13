<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

# read/write/store base confirguration
class BaseConfig {
	static [string] $Filename = ".config.txt"

	# save config file
	[void] Save([string] $fn) {
		$this | ConvertTo-Json | Out-File -FilePath $fn -Force
	}

	# check exists file and really parsed
	static [bool] Exists([string] $fn) {
		try {
			$hash = [BaseConfig]::Read($fn)
			if ($hash -is [Collections.Hashtable] -and $hash.Count -gt 0) {
				return $true
			}
		}
		catch { }
		return $false
	}

	static [void] Save([string] $fn, [Collections.Hashtable] $hash) {
		$hash | ConvertTo-Json | Out-File -FilePath $fn -Force
	}

	# read json config
	static [Collections.Hashtable] Read([string] $fn) {
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
	static [Collections.Hashtable] ReadOrCreate([string] $fn, [Collections.Hashtable] $hash) {
		try {
			$temp = Get-Content -Path $fn | ConvertFrom-Json
		}
		catch {
			$temp = $null
		}

		if ($temp) {
			$hash = @{}
			$temp | Get-Member -MemberType NoteProperty | ForEach-Object { $hash.Add($_.Name, $temp."$($_.Name)") }
			return $hash
		}
		else {
			$hash | ConvertTo-Json | Out-File -FilePath $fn -Force
			return $hash
		}
	}

	# read or create config
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
			$array | ConvertTo-Json | Out-File -FilePath $fn -Force
			return $array
		}
	}
}