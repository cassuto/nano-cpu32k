

 
 
 




window new WaveWindow  -name  "Waves for BMG Example Design"
waveform  using  "Waves for BMG Example Design"

      waveform add -signals /ip_bootrom_tb/status
      waveform add -signals /ip_bootrom_tb/ip_bootrom_synth_inst/bmg_port/CLKA
      waveform add -signals /ip_bootrom_tb/ip_bootrom_synth_inst/bmg_port/ADDRA
      waveform add -signals /ip_bootrom_tb/ip_bootrom_synth_inst/bmg_port/ENA
      waveform add -signals /ip_bootrom_tb/ip_bootrom_synth_inst/bmg_port/DOUTA

console submit -using simulator -wait no "run"
