<#
    .synopsis
        Standalone automatic Windows Update script

    .description
        Using wuapi, search for updates that are not installed, download them, and install them. Acccept EULAs and reboot if needed with
        no external input needed. Used with Task Scheduler to automate patching.

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
        Modify $updateSearch.Search("IsInstalled=0").Updates to change type of updates installed. Default is to return all not installed updates.
            Allowed methods:
            https://docs.microsoft.com/en-us/windows/desktop/api/wuapi/nf-wuapi-iupdatesearcher-search
        No warranty yadayadayada
#>

#Write start event for PatchScript
try {
    #start message in app logs, also check to make sure the source "patchscript" exists on machine
    Write-EventLog -LogName Application -Source "PatchScript" -EventId 59998 -EntryType Information -Message "Starting patching." -ErrorAction Stop
}

catch [System.InvalidOperationException] {
    #event source doesn't exist, create it on first run
    New-EventLog -Source "PatchScript" -LogName Application
    Write-EventLog -LogName Application -Source "PatchScript" -EventId 59998 -EntryType Information -Message "Starting patching."
}

#Search for, download, and install updates
try {
    #Create new update session and collection.
    $updateSession = New-Object -ComObject Microsoft.Update.Session
    $updateCollection = New-Object -ComObject Microsoft.Update.UpdateColl

    #Create update searcher and downloaders
    $updateSearch = $updateSession.CreateUpdateSearcher()
    $updateDownloader = $updateSession.CreateUpdateDownloader()

    #Perform search and get number of updates to install
    $searchResult = $updateSearch.Search("IsInstalled=0").Updates
    $numOfUpdates = $searchResult.Count

    if ($numOfUpdates -gt 0) {

        write-host("The following $numOfUpdates updates are being installed:")

        write-host("_______________________________________________________`n")

        foreach ($update in $searchResult) {
            $updatesInstalled += $update.Title + "`n"
            $updateInstalling = $update.Title
            $updateCollection.add($update)

            #Force accept EULA if needed
            if ($update.EulaAccepted -eq 0) {
                $update.AcceptEula()
            }

            #Create update downloader and download update
            $updateDownloader = $updateSession.CreateUpdateDownloader()
            $updateDownloader.Updates = $updateCollection
            $updateDownloader.Priority = 3
            write-host ("Downloading $updateInstalling ...")
            $downloadResult = $updateDownloader.Download()

            #Create update installer and install update
            $updateInstaller = $updateSession.CreateUpdateInstaller()
            $updateInstaller.Updates = $updateCollection
            write-host ("Installing $updateInstalling ...")
            $installResult = $updateInstaller.Install()

            $needReboot = $installResult.RebootRequired

            write-host ("Reboot Required: $needReboot")
            if ($installResult.RebootRequired) {
                $rebootRequired = $true
            }
        }

        #Fire event to event log that says which updates were installed and if a reboot was necessary.
        Write-EventLog -LogName Application -Source "PatchScript" -EventId 59999 -EntryType Information -Message "Installed the following patches:`n`n $updatesInstalled`n`n Rebooted: $rebootRequired"

        #Force reboot if needed.
        if ($rebootRequired) {
            Restart-Computer -Force
            }
        }

#No updates to install, fire event to log and stop. 
    Else {
        Write-EventLog -LogName Application -Source "PatchScript" -EventId 60000 -EntryType Information -Message "No updates to install."
        Write-Host("No updates to install.")
    }
}

#Errors found, fire event to log with details and stop.
catch {
    $errorMessage = $_.Exception.Message
    Write-EventLog -LogName Application -Source "PatchScript" -EventId 60001 -EntryType Error -Message "Did not install patches due to errors.`n`n $errorMessage `n`n Required patches: $updatesInstalled `n"
}