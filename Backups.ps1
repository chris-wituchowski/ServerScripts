$pcPath = 'C:\users\Chris'
$serverPath = '\\cwd130host001\C$\Shares\All Stuff\Current Data'

Start-Transcript -path C:\users\chris\Documents\Powershell\trans.txt

try {
    $serverFiles = get-childitem $serverPath -Recurse -ErrorAction Stop
    $pcFiles = Get-ChildItem $pcPath -Recurse -ErrorAction Stop
}
catch {
    Write-EventLog -LogName Application -Source "BackupScript" -EventId 6969 -EntryType Error -Message "Unable to run backup script, paths not found"
    break
}

try{
    $fileDiff = Compare-Object -ReferenceObject $pcFiles -DifferenceObject $serverFiles -PassThru
}
catch {
    Write-EventLog -LogName Application -Source "BackupScript" -EventId 6969 -EntryType Error -Message "Unable to run backup script, error differentiating paths"
    break
}


foreach($object in $fileDiff) {
    $serverRelativePath = $serverPath + (Split-Path $object.FullName -NoQualifier)
    if($object.SideIndicator -eq '=>') {
        write-host "$object item on server"
    }
    elseif($object.SideIndicator -eq '<='){
        try {
            Copy-Item -Path $object.FullName -Destination $serverRelativePath
        }
        catch {
            write-host ('Could not copy ' + $object.FullName)
            continue
        }
        write-host ($object.FullName + ' item on pc, moved to server ' + $serverRelativePath)
    }
    else {
        write-host 'item not found'
    }
}

Write-EventLog -LogName Application -Source "BackupScript" -EventId 6969 -EntryType Information -Message "Script completed without errors"