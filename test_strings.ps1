Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead('C:\Users\moham\Downloads\Jtak full data.xlsx')
$ssEntry = $zip.GetEntry('xl/sharedStrings.xml')
$ssStream = $ssEntry.Open()
$ssXml = [xml](New-Object System.IO.StreamReader($ssStream)).ReadToEnd()
$ssStream.Close()
$zip.Dispose()

Write-Host "Total strings in SST:" $ssXml.sst.si.Count
$badCount = 0
for ($i = 0; $i -lt [Math]::Min(100, $ssXml.sst.si.Count); $i++) {
    $text = $ssXml.sst.si[$i].InnerText
    Write-Host "Index $i : $text"
}
