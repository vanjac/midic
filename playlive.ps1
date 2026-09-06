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
	$start = 0
	foreach ($i in 1 .. $bytes.Length) {
		if (($i -eq $bytes.Length) -or (($bytes[$i] -band 0x80) -ne 0)) {
			$buf = $BufExt::AsBuffer($bytes[$start .. ($i - 1)])
			$port.SendBuffer($buf)
			$start = $i
		}
	}
}
