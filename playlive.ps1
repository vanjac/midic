Add-Type -AssemblyName System.Runtime.WindowsRuntime
$MidiSynth = [Windows.Devices.Midi.MidiSynthesizer,Windows.Devices.Midi,ContentType=WindowsRuntime]
$BufExt = [Runtime.InteropServices.WindowsRuntime.WindowsRuntimeBufferExtensions]

# https://fleexlab.blogspot.com/2018/02/using-winrts-iasyncoperation-in.html
$asTaskMethod = ([WindowsRuntimeSystemExtensions].GetMethods() | ? {
	$_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
	$_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
})[0]

$portAsync = $MidiSynth::CreateAsync()
$portTask = $asTaskMethod.MakeGenericMethod($MidiSynth).Invoke($null, @($portAsync))
$portTask.Wait()
$port = $portTask.Result

while ($true) {
	$in = Read-Host
	$bytes = [bigint]::Parse($in, 'HexNumber').ToByteArray()
	[array]::Reverse($bytes)
	$port.SendBuffer($BufExt::AsBuffer($bytes))
}
