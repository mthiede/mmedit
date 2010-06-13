# Run in non-Gem mode

$:.unshift File.join(File.dirname(__FILE__),"lib")
# Uncomment the following lines to also require rgen and concrete directly from source code
#$:.unshift File.join(File.dirname(__FILE__),"../rgen/lib")
#$:.unshift File.join(File.dirname(__FILE__),"../concrete/lib")

require 'MMEdit'

MMEdit.run
