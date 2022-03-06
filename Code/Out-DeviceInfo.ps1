<#
MindMiner  Copyright (C) 2017-2021  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

function Out-DeviceInfo ([bool] $OnlyTotal) {
	$valuesweb = [Collections.ArrayList]::new()
	$valuesapi = [Collections.ArrayList]::new()

	[bool] $newline = $false
	[Config]::ActiveTypes | Where-Object { $Devices.$_ -and $Devices.$_.Count -gt 0 } | ForEach-Object {
		$type = $_
		switch ($type) {
			([eMinerType]::CPU) {
				if ($OnlyTotal -or $Devices.$type.Count -eq 1) {
					$cpu = $Devices.$type[0]
					$format = if ($global:Admin) { "{0} x {1}: {2}, {3} Mhz, {4}/{5} Core/Thread, {6} %, {7} C, {8} W, {9}" } else { "{0} x {1}: {2}, {3} Mhz, {4}/{5} Core/Thread, {9}" }
					Write-Host ($format -f $type, $Devices.$type.Count, $cpu.Name, $cpu.Clock, $cpu.Cores, $cpu.Threads, $cpu.Load, $cpu.Temperature, $cpu.Power, $cpu.Features)
					Remove-Variable format, cpu
					$newline = $true;
				}
				else {
					if ($newline) {
						Write-Host
						$newline = $false
					}
					Write-Host "   Devices: $type"
					Write-Host
					$columns = [Collections.ArrayList]::new()
					$columns.AddRange(@(
						@{ Label="CPU"; Expression = { $_.Name } }
						@{ Label="Clock, MHz"; Expression = { $_.Clock }; Alignment = "Right" }
						@{ Label="Core/Thread"; Expression = { "$($_.Cores)/$($_.Threads)" }; Alignment = "Center" }
					))
					if ($global:Admin) {
						$columns.AddRange(@(
							@{ Label="Load, %"; Expression = { $_.Load }; Alignment = "Right" }
							@{ Label="Temp, C"; Expression = { $_.Temperature }; Alignment = "Right" }
							@{ Label="Power, W"; Expression = { $_.Power }; Alignment = "Right" }
						))
					}
					$columns.AddRange(@(
						@{ Label="Features"; Expression = { $_.Features } }
					))
					Out-Table ($Devices.$type | Format-Table $columns)
					Remove-Variable columns
				}
				if ($global:API.Running) {
					$columnsweb = [Collections.ArrayList]::new()
					$columnsweb.AddRange(@(
						@{ Label="CPU"; Expression = { $_.Name } }
						@{ Label="Clock, MHz"; Expression = { $_.Clock } }
						@{ Label="Core/Thread"; Expression = { "$($_.Cores)/$($_.Threads)" } }
					))
					if ($global:Admin) {
						$columnsweb.AddRange(@(
							@{ Label="Load, %"; Expression = { $_.Load } }
							@{ Label="Temp, C"; Expression = { $_.Temperature } }
							@{ Label="Power, W"; Expression = { $_.Power } }
						))
					}
					$columnsweb.AddRange(@(
						@{ Label="Features"; Expression = { $_.Features } }
					))
					
					$valuesweb.AddRange(@(($Devices.$type | Select-Object $columnsweb | ConvertTo-Html -Fragment)))
					Remove-Variable columnsweb
				}
			}
			{ $_ -eq [eMinerType]::nVidia -or $_ -eq [eMinerType]::AMD } {
				if ($OnlyTotal -or $Devices.$type.Count -eq 1) {
					$measure = $Devices.$type | Measure-Object "Clock", "ClockMem", "Load", "LoadMem", "Fan", "Temperature", "Power", "PowerLimit" -Min -Max
					$str = "$type x $($Devices.$type.Count): "
					if ($Devices.$type.Count -eq 1) { $str += "$($Devices.$type[0].name), " }
					if ($measure[0].Minimum -eq $measure[0].Maximum) { $str += "$($measure[0].Minimum)/" } else { $str += "$($measure[0].Minimum)-$($measure[0].Maximum)/" }
					if ($measure[1].Minimum -eq $measure[1].Maximum) { $str += "$($measure[1].Minimum) Mhz, " } else { $str += "$($measure[1].Minimum)-$($measure[1].Maximum) Mhz, " }
					if ($measure[2].Minimum -eq $measure[2].Maximum) { $str += "$($measure[2].Minimum)/" } else { $str += "$($measure[2].Minimum)-$($measure[2].Maximum)/" }
					if ($measure[3].Minimum -eq $measure[3].Maximum) { $str += "$($measure[3].Minimum) %, " } else { $str += "$($measure[3].Minimum)-$($measure[3].Maximum) %, " }
					if ($measure[4].Minimum -eq $measure[4].Maximum) { $str += "$($measure[4].Minimum) %, " } else { $str += "$($measure[4].Minimum)-$($measure[4].Maximum) %, " }
					if ($measure[5].Minimum -eq $measure[5].Maximum) { $str += "$($measure[5].Minimum) C, " } else { $str += "$($measure[5].Minimum)-$($measure[5].Maximum) C, " }
					if ($measure[6].Minimum -eq $measure[6].Maximum) { $str += "$($measure[6].Minimum) W, " } else { $str += "$($measure[6].Minimum)-$($measure[6].Maximum) W, " }
					if ($measure[7].Minimum -eq $measure[7].Maximum) { $str += "$($measure[7].Minimum) %W" } else { $str += "$($measure[7].Minimum)-$($measure[7].Maximum) %" }
					Write-Host $str
					Remove-Variable measure
					$newline = $true
				}
				else {
					if ($newline) {
						Write-Host
						$newline = $false
					}
					Write-Host "   Devices: $type"
					Write-Host
					$columns = [Collections.ArrayList]::new()
					$columns.AddRange(@(
						@{ Label="GPU"; Expression = { $_.Name } }
						@{ Label="Clock, MHz"; Expression = { "$($_.Clock)/$($_.ClockMem)" }; Alignment = "Center" }
						@{ Label="Load, %"; Expression = { "$($_.Load)/$($_.LoadMem)" }; Alignment = "Center" }
						@{ Label="Fan, %"; Expression = { $_.Fan }; Alignment = "Right" }
						@{ Label="Temp, C"; Expression = { $_.Temperature }; Alignment = "Right" }
						@{ Label="Power, W"; Expression = { $_.Power }; Alignment = "Right" }
						@{ Label="PL, %W"; Expression = { $_.PowerLimit }; Alignment = "Right" }
					))
					Out-Table ($Devices.$type | Format-Table $columns)
					Remove-Variable columns
				}
				if ($global:API.Running) {
					$columnsweb = [Collections.ArrayList]::new()
					$columnsweb.AddRange(@(
						@{ Label="GPU"; Expression = { $_.Name } }
						@{ Label="Clock, MHz"; Expression = { "$($_.Clock)/$($_.ClockMem)" }; }
						@{ Label="Load, %"; Expression = { "$($_.Load)/$($_.LoadMem)" }; }
						@{ Label="Fan, %"; Expression = { $_.Fan }; }
						@{ Label="Temp, C"; Expression = { $_.Temperature }; }
						@{ Label="Power, W"; Expression = { $_.Power }; }
						@{ Label="PL, %W"; Expression = { $_.PowerLimit }; }
					))
					$valuesweb.AddRange(@(($Devices.$type | Select-Object $columnsweb | ConvertTo-Html -Fragment)))
					Remove-Variable columnsweb
				}
			}
			default {}
		}
		if ($global:API.Running) {
			# api
			$valuesapi.AddRange(@(Get-DevicesForApi $type))
		}
	}
	if ($newline) { Write-Host }

	if ($global:API.Running) {
		$global:API.Device = $valuesweb
		$global:API.Devices = $valuesapi | ConvertTo-Json
	}
	Remove-Variable valuesapi, valuesweb
}

function Get-DevicesForApi ([Parameter(Mandatory)] [eMinerType] $type) {
	if ($Devices) {
		$columnsapi = [Collections.ArrayList]::new()
		switch ($type) {
			([eMinerType]::CPU) {
				$columnsapi.AddRange(@(
					@{ Label="type"; Expression = { "$type" } }
					@{ Label="name"; Expression = { $_.Name } }
					@{ Label="cores"; Expression = { $_.Cores } }
					@{ Label="threads"; Expression = { $_.Threads } }
					@{ Label="clock"; Expression = { $_.Clock } }
				))
				if ($global:Admin) {
					$columnsapi.AddRange(@(
						@{ Label="load"; Expression = { $_.Load } }
						@{ Label="temp"; Expression = { $_.Temperature } }
						@{ Label="power"; Expression = { $_.Power } }
					))
				}
			}
			{ $_ -eq [eMinerType]::nVidia -or $_ -eq [eMinerType]::AMD } {
				$columnsapi.AddRange(@(
					@{ Label="type"; Expression = { "$type" } }
					@{ Label="name"; Expression = { $_.Name } }
					@{ Label="clock"; Expression = { $_.Clock } }
					@{ Label="clockmem"; Expression = { $_.ClockMem } }
					@{ Label="load"; Expression = { $_.Load } }
					@{ Label="loadmem"; Expression = { $_.LoadMem } }
					@{ Label="fan"; Expression = { $_.Fan } }
					@{ Label="temp"; Expression = { $_.Temperature } }
					@{ Label="power"; Expression = { $_.Power } }
					@{ Label="pl"; Expression = { $_.PowerLimit } }
				))
			}
			Default {}
		}
		$Devices.$type | Select-Object $columnsapi
		Remove-Variable columnsapi
	}
}