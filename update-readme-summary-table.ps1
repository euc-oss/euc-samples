function Get-TextBetweenTwoStrings ([string]$startPattern, [string]$endPattern, [string]$filePath){
    # Get content from the input file
    $fileContent = Get-Content -Path $filePath -Raw
    # Regular expression (Regex) of the given start and end patterns
    $pattern = '(?is){0}(.*?){1}' -f [regex]::Escape($startPattern), [regex]::Escape($endPattern)
    # Perform the Regex operation and output
    return [regex]::Match($fileContent,$pattern).Groups[1].Value.ToString()
}

function ReplaceMarkdownTableContent {
    param(
        [string]$filePath,
        [string[]]$tableData
    )

    $index = (Get-Content $filePath | Select-String -Pattern "\| --- \| --- \| ---:\|").LineNumber

    if ($index) {
        $headerRow = $content[$index - 1]
        $newContent = $content[0..($index - 2)]

        #$tableRows = $tableData | ForEach-Object { write-host $_  }
        $tableRows = $tableData | ForEach-Object { }
        $newContent += $headerRow
        $newContent += $tableData

        Set-Content $filePath -Value $newContent
    } else {
        Write-Warning "Pattern '| --- | --- | ---:|' not found in the file."
    }
}

$current_path = (Get-Location).Path

$paths = @("Access-Samples",
"Android-Samples",
"App-Volumes-Samples",
"Horizon-Samples",
"Intelligence-Samples",
"UAG-Samples",
"UEM-Samples")

$startPattern = '<!-- Summary Start -->'
$endPattern   = '<!-- Summary End -->'

# find README.md files under each sample directory
foreach ($p in $paths) {

    $results = @()
    $files = Get-ChildItem -Path $p -Recurse -Include 'readme.md' -exclude 'docs/*' -Depth 5

    foreach ($f in $files) {
        #Write-Host("Working on $f") -ForegroundColor Green
        $match = Get-TextBetweenTwoStrings -startPattern $startPattern -endPattern $endPattern -filePath $f.FullName
        $summary = $match.Trim()
        $fulldirname = $f.DirectoryName
        $newpath = $fulldirname.Replace($current_path,"")
        $dirname = $f.Directory.Name
        $fname = $f.Name
        $link = [uri]::EscapeDataString(".$newpath/")

        $results += "| $dirname | $summary | [Link]($link) |"
    }
    
    #Write the results to the index file after the table header, replacing everything previous
    $docpath = "docs/$p/index.md"
    $file = Get-ChildItem -Path $docpath
    ReplaceMarkdownTableContent $file $results

}

