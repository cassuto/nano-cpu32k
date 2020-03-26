setMode -bs
setMode -bs
setMode -bs
setMode -bs
addDevice -p 1 -file "E:/_processor_cores/nano-cpu32k/sopc/fpga/xilinx-spartan6/ncpu32k-spartan6/toplevel.bit"
setCable -port auto
Program -p 1 
setMode -bs
setMode -bs
setMode -ss
setMode -sm
setMode -hw140
setMode -spi
setMode -acecf
setMode -acempm
setMode -pff
setMode -bs
saveProjectFile -file "E:\_processor_cores\nano-cpu32k\sopc\fpga\xilinx-spartan6\ncpu32k-spartan6\\auto_project.ipf"
setMode -bs
setMode -bs
deleteDevice -position 1
setMode -bs
setMode -ss
setMode -sm
setMode -hw140
setMode -spi
setMode -acecf
setMode -acempm
setMode -pff
