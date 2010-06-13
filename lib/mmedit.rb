require 'version'
require 'mmedit/data_provider'
require 'concrete/working_set'
require 'concrete/index_builder'
require 'concrete/util/logger'
require 'concrete/server'
require 'concrete/concrete_syntax_provider'
require 'concrete/config'

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
    logger = Concrete::Util::Logger.new

    workingSet = Concrete::WorkingSet.new(".")
    ARGV.each{|a| workingSet.addFile(a)}

    logger.info "Point your Firefox or Chrome to http://localhost:1234 ..."
    mm = RGen::ECore
    indexBuilder = Concrete::IndexBuilder.new(mm, :ignoreReferences => proc {|r| false })
    indexBuilder.indexMetamodel

    dataProvider = MMEdit::DataProvider.new(workingSet, mm, indexBuilder, logger)
    config = Concrete::Config.new(File.expand_path("~/.mmedit_config"))
    syntaxProvider = Concrete::ConcreteSyntaxProvider.new([File.dirname(__FILE__)+"/../syntax"], logger, config)
    Concrete::Server.new(workingSet, dataProvider, syntaxProvider, File.dirname(__FILE__)+"/../html").start
  end

end
