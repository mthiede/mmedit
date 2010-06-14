require 'rgen/metamodel_builder'

module StatemachineMetamodel
   extend RGen::MetamodelBuilder::ModuleExtension
   include RGen::MetamodelBuilder::DataTypes


   class Statemachine < RGen::MetamodelBuilder::MMBase
   end

   class State < RGen::MetamodelBuilder::MMBase
      has_attr 'name', String, :lowerBound => 1 
   end

   class Transition < RGen::MetamodelBuilder::MMBase
   end

end

StatemachineMetamodel::Statemachine.contains_many_uni 'states', StatemachineMetamodel::State 
StatemachineMetamodel::State.contains_many_uni 'transitions', StatemachineMetamodel::Transition 
StatemachineMetamodel::Transition.has_one 'targetState', StatemachineMetamodel::State 
