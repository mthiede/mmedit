# Run in non-Gem mode

$:.unshift File.join(File.dirname(__FILE__),"lib")
$:.unshift File.join(File.dirname(__FILE__),"../rgen/lib")
$:.unshift File.join(File.dirname(__FILE__),"../concrete/lib")

require 'MMEdit'

MMEdit.run
