require 'rgen/environment'
require 'rgen/instantiator/ecore_xml_instantiator'
require 'rgen/serializer/xmi20_serializer'
require 'mmgen/metamodel_generator'
require 'concrete/file_cache_map'
require 'concrete/util/string_writer'
require 'concrete/metamodel/ecore_to_concrete'
require 'rgen/serializer/json_serializer'
require 'rgen/instantiator/json_instantiator'

module MMEdit

class DataProvider
  include MMGen::MetamodelGenerator

  BuiltInIdent = "_builtin"

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

    trans = Concrete::Metamodel::ECoreToConcrete.new(nil, env, :featureFilter => proc{|f| !f.derived && f.name != "eSubTypes"})
    trans.trans(@mm.ecore.eAllClasses)

    writer = Concrete::Util::StringWriter.new
    ser = RGen::Serializer::JsonSerializer.new(writer, :leadingSeparator => false)
    ser.serialize(env.find(:class => Concrete::Metamodel::ConcreteMMM::Classifier))

    @metamodelAsJson = "var Metamodel = "+writer.string+";"
  end

  def indexMetamodelAsJson
    return @indexMetamodelAsJson if @indexMetamodelAsJson

    env = RGen::Environment.new
    trans = Concrete::Metamodel::ECoreToConcrete.new(nil, env)
    trans.trans(@indexBuilder.indexMetamodel.ecore.eAllClasses)

    writer = Concrete::Util::StringWriter.new
    ser = RGen::Serializer::JsonSerializer.new(writer, :leadingSeparator => false)
    ser.serialize(env.find(:class => Concrete::Metamodel::ConcreteMMM::Classifier))

    @indexMetamodelAsJson = "var IndexMetamodel = "+writer.string+";"
  end

  def getJsonModel(fileIdent)
    if (fileIdent == BuiltInIdent)
      builtInJsonModel
    else
      cachedData(fileIdent, @jsonModelCache)
    end
  end

  def createModule(fileIdent)
    return if fileIdent =~ /\.\./
    newfile = Pathname.new(@workingSet.rootPath + "/" + fileIdent).cleanpath.to_s

    unless File.exist?(newfile)
      @logger.info("Creating module #{newfile}")
      FileUtils.mkdir_p(File.dirname(newfile))

      root = RGen::ECore::EPackage.new(:name => "Untitled")
      if fileIdent =~ /\.ecore$/
        File.open(newfile,"w") do |f|
          ser = RGen::Serializer::XMI20Serializer.new(f)
          ser.serialize(root)
        end
      else
        generateMetamodel(root, newfile)
      end
    else
      @logger.info("Using existing module #{newfile}")
    end

    @workingSet.addFile(newfile)
  end

  def setJsonModel(fileIdent, data)
    return if (fileIdent == BuiltInIdent)

    env = RGen::Environment.new

    inst = RGen::Instantiator::JsonInstantiator.new(env, @mm, :separator => "/", :leadingSeparator => true)
    unresolvedReferences = inst.instantiate(data)

    resolveReferencesToBuiltins(unresolvedReferences)

    outfile = @workingSet.getFile(fileIdent)
    return unless outfile

    tempfile = outfile+".mmedit.tmp"
    root = env.find(:class => RGen::ECore::EPackage).find{|p| p.eSuperPackage.nil?}
    if fileIdent =~ /\.ecore$/
      File.open(tempfile,"w") do |f|
        ser = RGen::Serializer::XMI20Serializer.new(f)
        ser.serialize(root)
      end
    else
      generateMetamodel(root, tempfile)
    end
    FileUtils.mv(tempfile, outfile)

    @jsonModelCache.storeData(outfile, data)
    generateJsonIndex(outfile, root)
  end

  def getAllJsonIndex
  puts "load index"
    "[" + (@workingSet.fileIdentifiers + [BuiltInIdent]).collect do |ident|
      '{ "_class": "Module", "name": "'+ident+'", "elements":'+"\n"+getJsonIndex(ident)+"}"
    end.join(",\n") + "]"
  end

  private

  def getJsonIndex(fileIdent)
    if (fileIdent == BuiltInIdent)
      builtInJsonIndex
    else
      cachedData(fileIdent, @jsonIndexCache)
    end
  end

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
    if file =~ /\.ecore$/
      rootp = loadECoreMetamodel(file)
    else
      rootp = loadRGenMetamodel(file)
    end
    generateJsonModel(file, rootp)
    generateJsonIndex(file, rootp)
  end

  def generateJsonModel(file, root)
    @logger.info "caching json model..."
    writer = Concrete::Util::StringWriter.new
    ser = RGen::Serializer::JsonSerializer.new(writer)
    ser.serialize(root)
    @jsonModelCache.storeData(file, writer.string)
  end

  def generateJsonIndex(file, root)
    @logger.info "caching json index..."
    index = @indexBuilder.buildIndex(root)
    writer = Concrete::Util::StringWriter.new
    ser = RGen::Serializer::JsonSerializer.new(writer)
    ser.serialize(index)
    @jsonIndexCache.storeData(file, writer.string)
  end

  def self.removeLoadContainer
    remove_const(:LoadContainer) if const_defined?(:LoadContainer)
  end

  def loadRGenMetamodel(file)
    self.class.removeLoadContainer
    eval("module LoadContainer; end")  
    LoadContainer.module_eval(File.read(file))
    mmname = LoadContainer.constants.find{|c| LoadContainer.const_get(c).respond_to?(:ecore)}
    LoadContainer.const_get(mmname).ecore
  end

  def loadECoreMetamodel(file)
    env = RGen::Environment.new
    File.open(file) do |f|
      ECoreXMLInstantiator.new(env).instantiate(f.read)
    end
    env.find(:class => RGen::ECore::EPackage).find{|p| p.eSuperPackage.nil?}
  end

  def builtInJsonModel
    writer = Concrete::Util::StringWriter.new
    ser = RGen::Serializer::JsonSerializer.new(writer)
    ser.serialize(builtInModel)
    writer.string
  end

  def builtInJsonIndex
    index = builtInModel.collect{|e| @indexBuilder.buildIndex(e)}
    writer = Concrete::Util::StringWriter.new
    ser = RGen::Serializer::JsonSerializer.new(writer)
    ser.serialize(index)
    writer.string
  end

  def builtInModel
    [
      RGen::ECore::EString,
      RGen::ECore::EInt,
      RGen::ECore::EBoolean,
      RGen::ECore::EFloat,
      RGen::ECore::ERubyObject,
      RGen::ECore::EJavaObject,
      RGen::ECore::ERubyClass,
      RGen::ECore::EJavaClass
    ]
  end

  def resolveReferencesToBuiltins(unresolvedReferences)
    unresolvedReferences.each do |ur|
      target = case ur.proxy.targetIdentifier
        when "/EString"; RGen::ECore::EString
        when "/EInt"; RGen::ECore::EInt
        when "/EFloat"; RGen::ECore::EFloat
        when "/EBoolean"; RGen::ECore::EBoolean
        when "/EJavaObject"; RGen::ECore::EJavaObject
        when "/EJavaClass"; RGen::ECore::EJavaClass
        when "/ERubyObject"; RGen::ECore::ERubyObject
        when "/ERubyClass"; RGen::ECore::ERubyClass
        else
          nil
      end
      if ur.element.hasManyMethods(ur.featureName)
        ur.element.removeGeneric(ur.featureName, ur.proxy)
        ur.element.addGeneric(ur.featureName, target)
      else
        # this will replace the proxy
        ur.element.setGeneric(ur.featureName, target)
      end
    end
  end

end

end

