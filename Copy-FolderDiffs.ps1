<#
    .synopsis
        Folder differential backup script

    .description
        Compares the full recursive contents of two paths and copies files missing from the destination over from the source.

    .Parameters
        None

    .INputs
        None

    .OUTputs
        None

    .Notes
        Version: 0.1
        Author: Chris Wituchowski
        Creation Date: 8/31/2018
        Purpose: Initial script development
        Modify $pcPath and $serverPath with the appropriate folders you want to copy from and copy to.
        No warranty yadayadayada
#>

#source and destination paths
$pcPath = <SourcePath>
$serverPath = <DestinationPath>

#check if path are valid
try {
    $serverFiles = get-childitem $serverPath -Recurse -ErrorAction Stop
    $pcFiles = Get-ChildItem $pcPath -Recurse -ErrorAction Stop
}
catch {
    Write-EventLog -LogName Application -Source "BackupScript" -EventId 6969 -EntryType Error -Message "Unable to run backup script, paths not found"
    exit
}

#find differences between the two folders being compared
try{
    $fileDiff = Compare-Object -ReferenceObject $pcFiles -DifferenceObject $serverFiles -PassThru
}
catch {
    Write-EventLog -LogName Application -Source "BackupScript" -EventId 6970 -EntryType Error -Message "Unable to run backup script, error differentiating paths"
    exit
}

#for each object not found on the destination, copy it over
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

Write-EventLog -LogName Application -Source "BackupScript" -EventId 6971 -EntryType Information -Message "Script completed without errors"