<#
MindMiner  Copyright (C) 2017-2020  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

$Download = $args

$Download | ForEach-Object {
	$URI = $_.URI
	$Path = $_.Path
	$Pass = $_.Pass
	$Dir = Split-Path -Path $Path
	$FN = Split-Path -Leaf $URI
	$Archive = [IO.Path]::Combine($Dir, $FN)

	# "'$URI' '$Path' '$Dir' '$FN' '$Archive' " | Out-File "$FN.txt"

	if (![string]::IsNullOrWhiteSpace($Dir) -and !(Test-Path $Dir)) {
		New-Item -ItemType Directory $Dir | Out-Null
	}

	if (!(Test-Path $Path)) {
		[Diagnostics.Process] $process = $null
		try {
			if ([Net.ServicePointManager]::SecurityProtocol -notmatch [Net.SecurityProtocolType]::Tls12) {
				[Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12
			}
			$req = Invoke-WebRequest $URI -OutFile $Archive -PassThru -ErrorAction Stop -UseBasicParsing
			# names not match - upack
			if ((Split-Path -Leaf $Path) -ne $FN) {
				$p = [string]::Empty
				if (![string]::IsNullOrWhiteSpace($Pass)) {
					$p = "-p$Pass"
				}
				if ([string]::IsNullOrWhiteSpace($Dir)) {
					$process = Start-Process "7z" "x $Archive -y -spe $p" -Wait -WindowStyle Hidden -PassThru
				}
				else {
					$process = Start-Process "7z" "x $Archive -o$Dir -y -spe $p" -Wait -WindowStyle Hidden -PassThru
				}
				# remove archive
				Remove-Item $Archive -Force
				if ($process.ExitCode -eq 0) {
					if (!(Test-Path $path -PathType Leaf)) {
						# if has one subfolder - delete him
						Get-ChildItem $Dir | Where-Object PSIsContainer -EQ $true | ForEach-Object {
							$parent = "$Dir\$_"
							Get-ChildItem "$parent" | ForEach-Object { Move-Item "$parent\$_" "$Dir" -Force }
							Remove-Item $parent -Force
						}
					}
					Get-ChildItem $Dir -File -Recurse | Unblock-File
				}
				elseif (![string]::IsNullOrWhiteSpace($Dir)) {
					# clear folder if error
					Remove-Item $Dir -Force
				}
			}
		}
		catch {
			# "'$URI' '$Path' '$Dir' '$FN' '$Archive' $_" | Out-File "$FN.txt" -Append
		}
		finally {
			if ($process -is [IDisposable]) { $process.Dispose(); $process = $null }
			if ($req -is [IDisposable]) { $req.Dispose(); $req = $null }
		}
	}
}