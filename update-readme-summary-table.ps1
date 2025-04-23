<# Workspace ONE Script Importer

  .SYNOPSIS
    This Powershell script builds the index tables that feeds into the https://developer.omnissa.com portal
  .NOTES
    Created:   	    August, 2024
    Created by:	    Richard Croft
    Contributors:   Phil Helmling, Omnissa
    Organization:   Omnissa, LLC
    Github:         https://github.com/euc-oss/euc-samples

  .DESCRIPTION
    This script builds the index tables that feeds into the https://developer.omnissa.com portal. The tables are written as Markdown into the /docs folder. There is one table per area:
    * Access-Samples
    * Android-Samples
    * App-Volumes-Samples
    * Horizon-Samples
    * Intelligence-Samples
    * UAG-Samples
    * UEM-Samples
    * UEM-Samples/Scripts
    * UEM-Samples/Sensors

#>

function Get-TextBetweenTwoStrings {
    param(
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)] [ValidateNotNullOrEmpty()] [string] $startPattern,
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)] [ValidateNotNullOrEmpty()] [string] $endPattern,
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)] [ValidateNotNullOrEmpty()] [string] $filePath
    )
    
    # Get content from the input file
    $fileContent = Get-Content -Path $filePath -Raw
    # Regular expression (Regex) of the given start and end patterns
    $pattern = '(?is){0}(.*?){1}' -f [regex]::Escape($startPattern), [regex]::Escape($endPattern)
    # Perform the Regex operation and output
    return [regex]::Match($fileContent,$pattern).Groups[1].Value.ToString()
}

#function Get-Description ([string]$filePath){
function Get-Description {
    param(
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)] [ValidateNotNullOrEmpty()] [string] $filePath
    )
    
    $fileContent = Get-Content -Path $filePath
    
    $d = $fileContent | Select-String -Pattern 'Description: ' -Raw -ErrorAction SilentlyContinue

    if($d){$description = $d.Substring($d.LastIndexOf('Description: ')+13) -replace '[#]' -replace '"',"" -replace "'",""}else{$Description = $null}
    return $description
}

function ReplaceMarkdownTableContent {
    param(
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)] [ValidateNotNullOrEmpty()] [string] $filePath,
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)] [ValidateNotNullOrEmpty()] [string[]] $tableData
    )

    $newContent = $null
    $content = Get-Content $filePath
    $index = ($content | Select-String -Pattern "\| --- \| --- \| ---:\|").LineNumber
    
    if ($index) {
        $newContent = $content[0..($index - 1)]
        $newContent += $tableData | ForEach-Object { $_ }
        Set-Content $filePath -Value $newContent
    } else {
        Write-Warning "Pattern '| --- | --- | ---:|' not found in the file {0}." -f $filePath
    }
}

function ReplaceScriptSensorMarkdownTableContent {
    param(
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)] [ValidateNotNullOrEmpty()] [string] $filePath,
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)] [ValidateNotNullOrEmpty()] [string[]] $tableData
    )

    $newContent = $null
    $content = Get-Content $filePath
    $index = ($content | Select-String -Pattern "\| --- \| --- \| --- \| ---:\|").LineNumber
    
    if ($index) {
        $newContent = $content[0..($index - 1)]
        $newContent += $tableData | ForEach-Object { $_ }
        Set-Content $filePath -Value $newContent
    } else {
        Write-Warning "Pattern '| --- | --- | --- | ---:|' not found in the file {0}." -f $filePath
    }
}

$current_path = (Get-Location).Path
$repo = "https://github.com/euc-oss/euc-samples"
$repopath = "$repo/tree/main"

function updateMainIndexes {
    $paths = @("Access-Samples",
    "Android-Samples",
    "App-Volumes-Samples",
    "DEEM-Samples",
    "Horizon-Samples",
    "Intelligence-Samples",
    "UAG-Samples",
    "UEM-Samples")
    
    $startPattern = '<!-- Summary Start -->'
    $endPattern   = '<!-- Summary End -->'

    # find README.md files under each sample directory
    foreach ($p in $paths) {

        $results = @()
        $files = Get-ChildItem -Path $p -Recurse -Include 'readme.md' -File

        foreach ($f in $files) {
            #Write-Host("Working on $f") -ForegroundColor Green
            $match = Get-TextBetweenTwoStrings -startPattern $startPattern -endPattern $endPattern -filePath $f.FullName
            
            $summary = $match.Trim()
            $fulldirname = $f.DirectoryName
            $newpath = $fulldirname.Replace($current_path,"")
            $dirname = $f.Directory.Name
            
            $URI = $repopath,$newpath -join ""
            $link = [uri]::EscapeUriString($URI)
            $results += "| $dirname | $summary | [Link]($link) |"

        }
        
        #Write the results to the index file after the table header, replacing everything previous
        $docpath = "docs/$p/index.md"
        $file = Get-ChildItem -Path $docpath
        ReplaceMarkdownTableContent -filePath $file -tableData $results

    }
}

function updateSensorScriptIndexes {
    $paths = @("scripts",
    "sensors")
    
    # find README.md files under each sample directory
    foreach ($p in $paths) {

        $results = @()
        $ExcludedTemplates = "import_script_samples|template*|import_sensor_samples|get_enrollment_sid_32_64|check_matching_sid_sensor|readme|README"
        $files = Get-ChildItem -Path "UEM-Samples/$p" -Recurse -File | Where-Object Name -NotMatch $ExcludedTemplates

        foreach ($f in $files) {
            #Write-Host $f
            $match = Get-Description -filePath $f.FullName
            $summary = $match.Trim()
            $fname = $f.Name
            $fullName = $f.FullName
            $dirname = $f.Directory.Name
            $newpath = $fullName.Replace($current_path,"")

            $URI = $repopath,$newpath -join ""
            $link = [uri]::EscapeUriString($URI)
            $results += "| $dirname | $fname | $summary | [$fname]($link) |"
            #Write-Host "| $dirname | $fname | $summary | [$fname]($link) |"
        }
        
        #Write the results to the index file after the table header, replacing everything previous
        $docpath = "docs/UEM-Samples/$p-index.md"
        $file = Get-ChildItem -Path $docpath
        ReplaceScriptSensorMarkdownTableContent -filePath $file -tableData $results

    }
}
# Update main indexes
updateMainIndexes

# Update Scripts and Sensor indexes
updateSensorScriptIndexes

