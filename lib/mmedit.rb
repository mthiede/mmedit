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

    edit

    exit(0)
  end

  def self.edit
    logger = Concrete::Util::Logger.new

    workingSet = Concrete::WorkingSet.new(".")
    ARGV.each{|a| workingSet.addFile(a)}

    logger.info "Point your Firefox or Chrome to http://localhost:1234 ..."
    mm = RGen::ECore
    indexBuilder = Concrete::IndexBuilder.new(mm)
    indexBuilder.indexMetamodel

    userHome = File.expand_path("~")
    logger.info "User syntax load dir: #{userHome}/.mmedit"
    syntaxDirs = [File.dirname(__FILE__)+"/../syntax", userHome+"/.mmedit"]

    dataProvider = MMEdit::DataProvider.new(workingSet, mm, indexBuilder, logger)
    config = Concrete::Config.new(File.expand_path("~/.mmedit_config"))
    syntaxProvider = Concrete::ConcreteSyntaxProvider.new(syntaxDirs, logger, config)
    Concrete::Server.new(workingSet, dataProvider, syntaxProvider, File.dirname(__FILE__)+"/../html").start
  end

end
