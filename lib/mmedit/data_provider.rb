require 'rgen/environment'
require 'mmgen/metamodel_generator'
require 'concrete/file_cache_map'
require 'concrete/util/string_writer'
require 'concrete_support/ecore_to_concrete'
require 'concrete_support/json_serializer'
require 'concrete_support/json_instantiator'

module MMEdit

class DataProvider

  def initialize(workingSet, mm, indexBuilder, logger)
    @workingSet = workingSet
    @mm = mm
    @indexBuilder = indexBuilder
    @logger = logger
    @jsonModelCache = Concrete::FileCacheMap.new(".mmedit", ".json")
    @jsonModelCache.versionInfo = MMEDIT_VERSION
    @jsonIndexCache = Concrete::FileCacheMap.new(".mmedit", ".index")
    @jsonIndexCache.versionInfo = MMEDIT_VERSION
  end

  def metamodelAsJson
    return @metamodelAsJson if @metamodelAsJson

    env = RGen::Environment.new

    trans = ConcreteSupport::ECoreToConcrete.new(nil, env)
    trans.trans(@mm.ecore.eAllClasses)

    writer = Concrete::Util::StringWriter.new
    ser = ConcreteSupport::JsonSerializer.new(writer, :leadingSeparator => false)
    ser.serialize(env.find(:class => ConcreteSupport::ConcreteMMM::Classifier))

    @metamodelAsJson = "var Metamodel = "+writer.string+";"
  end

  def indexMetamodelAsJson
    return @indexMetamodelAsJson if @indexMetamodelAsJson

    env = RGen::Environment.new
    trans = ConcreteSupport::ECoreToConcrete.new(nil, env)
    trans.trans(@indexBuilder.indexMetamodel.ecore.eAllClasses)

    writer = Concrete::Util::StringWriter.new
    ser = ConcreteSupport::JsonSerializer.new(writer, :leadingSeparator => false)
    ser.serialize(env.find(:class => ConcreteSupport::ConcreteMMM::Classifier))

    @indexMetamodelAsJson = "var IndexMetamodel = "+writer.string+";"
  end

  def getJsonModel(fileIdent)
    cachedData(fileIdent, @jsonModelCache)
  end

  def setJsonModel(fileIdent, data)
    env = RGen::Environment.new

    inst = ConcreteSupport::JsonInstantiator.new(env, @mm, :separator => "/", :leadingSeparator => true)
    inst.instantiate(data)

    outfile = @workingSet.getFile(fileIdent)
    return unless outfile

    tempfile = outfile+".mmedit.tmp"
    root = env.find(:class => RGen::ECore::EPackage).find{|p| p.eSuperPackage.nil?}
    generateMetamodel(root, tempfile)
    FileUtils.mv(tempfile, outfile)

    @jsonModelCache.storeData(outfile, data)
    generateJsonIndex(outfile, root)
  end

  def getJsonIndex(fileIdent)
    cachedData(fileIdent, @jsonIndexCache)
  end

  def getAllJsonIndex
    "[" + @workingSet.fileIdentifiers.collect do |ident|
      '{ "_class": "Module", "name": "'+ident+'", "elements":'+"\n"+getJsonIndex(ident)+"}"
    end.join(",\n") + "]"
  end

  private

  def cachedData(fileIdent, cache)
    infile = @workingSet.getFile(fileIdent)
    return unless infile
    outdata = cache.loadData(infile)
    if outdata == :invalid
      generateArtefacts(infile)
      outdata = cache.loadData(infile)
    end
    outdata
  end

  def generateArtefacts(file)
    mm = loadMetamodel(file)
    generateJsonModel(file, mm.ecore)
    generateJsonIndex(file, mm.ecore)
  end

  def generateJsonModel(file, root)
    @logger.info "caching json model..."
    writer = Concrete::Util::StringWriter.new
    ser = ConcreteSupport::JsonSerializer.new(writer)
    ser.serialize(root)
    @jsonModelCache.storeData(file, writer.string)
  end

  def generateJsonIndex(file, root)
    @logger.info "caching json index..."
    index = @indexBuilder.buildIndex(root)
    writer = Concrete::Util::StringWriter.new
    ser = ConcreteSupport::JsonSerializer.new(writer)
    # do not output file node to avoid file name dependency
    ser.serialize(index.elements)
    @jsonIndexCache.storeData(file, writer.string)
  end

  def loadMetamodel(file)
    self.class.const_remove("LoadContainer")
    eval("module LoadContainer; end")  
    LoadContainer.module_eval(File.read(file))
    LoadContainer.constants.find{|c| LoadContainer.const_get(c).respond_to?(:ecore)}
  end

end

end

