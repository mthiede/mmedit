require 'version'

module MMEdit

  def self.run
    puts "mmedit #{MMEDIT_VERSION}"
    puts

    if ARGV.size > 0
      edit
    else
      puts "Usage: mmedit <metamodel file>"
    end

    exit(0)
  end

  def self.edit
    require 'mmedit/data_provider'
    require 'concrete/working_set'
    require 'concrete/index_builder'
    require 'concrete/util/logger'
    require 'concrete/server'

    logger = Concrete::Util::Logger.new

    workingSet = Concrete::WorkingSet.new(".")
    ARGV.each{|a| workingSet.addFile(a)}

    logger.info "starting..."
    mm = RGen::ECore
    indexBuilder = Concrete::IndexBuilder.new(mm, :ignoreReferences => proc {|r| false })
    indexBuilder.indexMetamodel

    dataProvider = MMEdit::DataProvider.new(workingSet, mm, indexBuilder, logger)
    Concrete::Server.new(workingSet, dataProvider, File.dirname(__FILE__)+"/../html").start
  end

end
