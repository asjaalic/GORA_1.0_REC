# General read and formatting functions
#--------------------------------------

function read_from_file_to_dict!(f, vars::Dict{Symbol,Bool})
  for line in eachline(f)
    if !isempty(strip(line)) && !startswith(strip(line), "#")
      var, val = strip.(split(line, "="))
      try
        vars[Symbol(strip(var))] = parse(Bool, val)
      catch
      end

    end
  end
  return vars
end

function read_from_file_to_dict!(f, vars::Dict{Symbol,Float64})
  for line in eachline(f)
    if !isempty(strip(line)) && !startswith(strip(line), "#")
      var, val = strip.(split(line, "="))
      try
        vars[Symbol(strip(var))] = parse(Float64, val)
      catch
      end

    end
  end
  return vars
end

function read_from_file_to_dict!(f, vars::Dict{Symbol,String})
  for line in eachline(f)
    if !isempty(strip(line)) && !startswith(strip(line), "#")
      var, val = strip.(split(line, "="))
      try
        vars[Symbol(strip(var))] = val
      catch
      end
    end
  end
  return vars
end

function read_from_file_to_dict!(f, vars::Dict{Symbol,Any})
  for line in eachline(f)
    if !isempty(strip(line)) && !startswith(strip(line), "#")
      var, val = strip.(split(line, "="))
      try
        vars[Symbol(strip(var))] = val
      catch
      end
    end
  end
  return vars
end

function read_from_file_to_dict!(f, vars::Dict{Symbol,Number})
  # Use Dict{Symbol, Number} to allow float and int values
  # NB: all vaues read as float from file initially
  for line in eachline(f)
    if !isempty(strip(line)) && !startswith(strip(line), "#")
      var, val = strip.(split(line, "="))
      try
        vars[Symbol(strip(var))] = parse(Float64, val)
      catch
      end
    end
  end
  return vars
end

function read_type_to_dict(file, type::DataType)
  f = open(file)
  paramDict = Dict{Symbol,type}()
  paramDict = read_from_file_to_dict!(f, paramDict)

  return paramDict
end

function set_integers!(paramDict, integers)
  for (key, value) in paramDict
    if key in integers
      paramDict[key] = parse(Int64,value)
    end
  end
  return paramDict
end

function set_floats!(paramDict, float)
  for (key, value) in paramDict
    if key in float
      paramDict[key] = parse(Float64,value)
    end
  end
  return paramDict
end

function set_vector!(paramDict, vector)
  value = paramDict[vector]
  items = split(value," ")
  number = length(items)
  vec=zeros(Int64,number)
  for i=1:number
    vec[i]=parse(Int64,items[i])
  end
 
  return vec
end

function read_csv(file, path)
  try
    println("Reading from: ", file)
    data = Matrix{Float64}(CSV.read(joinpath(path, file), DataFrame, header = false)) # €/MWh
    return data
  catch e
    println("Can't read ", file)
    throw(error())
  end
end

# Functions to read and prep from predefined files
#-----------------------------------------

# parameters
function read_parameters_from_config_file(file = "configParameters.in")

  #paramDict = read_type_to_dict(file,Number)
  paramDict = read_type_to_dict(file, Any)

  integers =[:NStates]
  paramDict = set_integers!(paramDict, integers)

  floats =[:NYears :Big :NHoursStep]
  paramDict = set_floats!(paramDict,floats)

  #paramDict[:NSteps] = Int(paramDict[:NYears]*8760/paramDict[:NHoursStep])
  #paramDict[:NStages] = Int(paramDict[:NYears]*2)
  #paramDict[:NHoursStage] = Int(paramDict[:NSteps]/paramDict[:NStages])

  println("Parameters to be used:", paramDict)
  inputData = InputParam(;paramDict...)

  return inputData
end

function read_solverParameters_from_file(file = "solverParameters.in")
  try
    println("Reading solver parameters from config file.")
    #paramDict = read_type_to_dict(file, Number)
    paramDict = read_type_to_dict(file, Any)

    #integers = [:CPX_PARAM_SCRIND :CPX_PARAM_PREIND :CPX_PARAM_TILIM :CPX_PARAM_THREADS]
    integers = [:CPX_PARAM_SCRIND :CPX_PARAM_PREIND :CPX_PARAM_TILIM :CPX_PARAM_THREADS]
    paramDict = set_integers!(paramDict, integers)

    floats = [:CPXPARAM_MIP_Tolerances_MIPGap]
    paramDict = set_floats!(paramDict,floats)

    inputData = SolverParam(; paramDict...)

    return inputData
  catch e
    println("Can't set solver parameters.")
    throw(error())
  end
end


function set_parameters(runMode::runModeParam, case::caseData)
  try
    if runMode.setInputParameters
      println("Reading parameters from configuration file.")
      InputParameters = read_parameters_from_config_file("configParameters.in")
    else
      println("Reading inputparameters from JLD file.")
      InputFromFile = read_input_from_jld(case.InputPath, case.InputCase, "InputParam.jld")
      InputParameters = InputFromFile["InputParameters"]
    end

    return InputParameters
  catch e
    println("Can't set input parameters.")
    throw(error())
  end
end


function set_solverParameters()
  solverParameters = read_solverParameters_from_file()
  return solverParameters
end

function define_state_variables(InputParameters::InputParam,Battery::BatteryParam)
  
  @unpack (NStates) = InputParameters
  @unpack (min_SOC, energy_Capacity) = Battery   

  seg = [energy_Capacity-(energy_Capacity-min_SOC)*(1/(NStates-1)*(iState-1)) for iState=1:NStates]

  return states(
    seg
    )
end

# MODE SETTING
function read_runMode_file(file = "runMode.in")

  runModeDict = read_type_to_dict(file, Bool)
  runMode = runModeParam(; runModeDict...)

  println(runMode)

  return runMode
end


# INDIRIZZI CARTELLE - CASE SETTINGS
function set_runCase(file = "runCase.in")

  runCaseDict = read_type_to_dict(file, String)
  case = caseData(; runCaseDict...)

  println(caseData)

  return case
end

# BATTERY PARAMETERS SETTING
function set_battery_system(runMode::runModeParam, case::caseData)
  try
    if runMode.batterySystemFromFile
      println("Reading batterys characteristics from input files")
      Battery = read_Battery_from_file("BatteryCharacteristics.in")
    else
      println("Reading battery from JLD file.")
      InputFromFile = read_input_from_jld(case.InputPath, case.InputCase, "BatteryCharacteristics.jld")
      Battery = InputFromFile["BatteryCharacteristics"]
    end
    return Battery
  catch e
    println("Can't set battery parameters.")
    throw(error())
  end
end

function read_Battery_from_file(file = "BatteryCharacteristics.in")

  paramDict = read_type_to_dict(file, Any)
  println("Parameters to be used:", paramDict)

  floats =[:grid_Capacity :min_SOC :energy_Capacity :power_Capacity :Eff_charge :Eff_discharge :PV_max]
  paramDict = set_floats!(paramDict,floats)

  integers=[:NFull]
  paramDict = set_integers!(paramDict,integers)

  vec1 = :DoD
  DoD = set_vector!(paramDict,vec1)
  vec2 = :NCycles
  NCycles = set_vector!(paramDict,vec2)

  Battery = BatteryParam(;paramDict...,DoD,NCycles)
  #Battery = BatteryParam(;paramDict...,)

  return Battery
end


function read_input_from_jld(InputPath, InputCase, filname)
  inputFile = InputCase * filname
  try
    InputFromFile = load(joinpath(InputPath, inputFile))
    return InputFromFile
  catch e
    println(string("Could not read input: ", inputFile))
  end
end


# set case run name for saving results

function set_run_name(case, ResultPath, InputParameters)

  @unpack (NStages, NStates) = InputParameters
  param = string("NStages_",NStages,"NStates_",NStates)

  Finalpath = joinpath(ResultPath, splitdir(case.DataPath)[end])
  Finalpath = joinpath(Finalpath, param)

  runName = string(date, case.CaseName)

  println(string("Run name: ", runName))
  println(string("Result directory: ", joinpath(Finalpath, runName)))

  return joinpath(Finalpath, runName)
end

# CALCOLO INCENTIVI
function calculate_incentives(Power_prices,grid_Capacity,PV_cont,sud,centro,nord)

  l= length(Power_prices);
  tariffa_premio = zeros(l);
  tariffa_fotovoltaico = 0;

  # Calcolo Incentivo per Shared Energy a seconda della potenza dell'impianto e prezzi zonali  - Valori espressi in €/kWh
  if grid_Capacity > 600
    for i=1:l
      tariffa_premio[i] = min(100/1000,60/1000+max(0,180/1000-Power_prices[i]))
    end
  elseif grid_Capacity>200 && grid_Capacity<=600
    for i=1:l
      tariffa_premio[i] = min(110/1000,70/1000+max(0,180/1000-Power_prices[i]))
    end
  elseif grid_Capacity<=200
    for i=1:l
      tariffa_premio[i] = min(120/1000,80/1000+max(0,180/1000-Power_prices[i]))
    end
  end

  # Calcolo tariffa poer Impianti fotovoltaico a seconda della zona
  if sud
    tariffa_fotovoltaico = 0
  elseif centro
    tariffa_fotovoltaico = 4/1000
  elseif nord
    tariffa_fotovoltaico = 10/1000
  end

  return tariffa_premio,tariffa_fotovoltaico
end


