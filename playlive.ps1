Add-Type -AssemblyName System.Runtime.WindowsRuntime
$MidiSynthesizer = `
	[Windows.Devices.Midi.MidiSynthesizer, Windows.Devices.Midi, ContentType=WindowsRuntime]

# https://fleexlab.blogspot.com/2018/02/using-winrts-iasyncoperation-in.html
$asTaskMethod = ([WindowsRuntimeSystemExtensions].GetMethods() | ? {
	$_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
	$_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
})[0]

$portAsync = $MidiSynthesizer::CreateAsync()
$portTask = $asTaskMethod.MakeGenericMethod($MidiSynthesizer).Invoke($null, @($portAsync))
$portTask.Wait()
$port = $portTask.Result

while ($true) {
	$in = Read-Host
	$bytes = [bigint]::Parse($in, 'HexNumber').ToByteArray()
	[array]::Reverse($bytes)
	$buf = [Runtime.InteropServices.WindowsRuntime.WindowsRuntimeBufferExtensions]::AsBuffer($bytes)
	$port.SendBuffer($buf)
}
