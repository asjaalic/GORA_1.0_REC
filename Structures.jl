# STRUCTURES USED IN THE PROBLEM

# Input data
#-----------------------------------------------

# Input parameters 
@with_kw struct InputParam{F<:Float64,I<:Int}
    NYears::F
    NHoursStep::F
    NStates::I                                    #Number of possible states for each stage
    Big::F                                        #A big number
end

# Battery's characteristics
@with_kw struct BatteryParam{F<:Float64,I<:Int}
    grid_Capacity::F
    min_SOC::F                                   # Batter's maximum capacity
    energy_Capacity::F                                  # Battery's maximum energy storage capacity
    power_Capacity::F
    Eff_charge::F
    Eff_discharge::F
    NFull::I
    PV_max::F
    DoD::Any
    NCycles::Any
end

  
# Indirizzi cartelle
@with_kw struct caseData{S<:String}
    DataPath::S
    InputPath::S
    ResultPath::S
    CaseName::S
end

# runMode Parameters
@with_kw mutable struct runModeParam{B<:Bool}

    #runMode self defined reading of input 
    setInputParameters::B = true            #from .in file

    batterySystemFromFile::B = true
    productionPV::B = true
   
    battery_replacement::B = true           
    excel_savings::B = false
    plot_savings::B = true

    sud::B 
    centro::B
    nord::B

    # SIM settings
    dynamicProgramming::B= true
    simulate::B = true
    parallellSim::B = false
   
end

struct Results_dp
    Power_prices::Any
    battery_cost::Any
    pv_prod::Any
    load::Any
    incentivo::Any
    BESS_charge::Any
    BESS_discharge::Any
    PV_grid::Any
    charge_from_PV::Any
    degradation::Any
    shared_energy::Any
    gain::Any
    revenues_shared_energy::Any
    replacementCost::Any
    val::Any
    optimalValueStates::Any
    optimalfromState::Any
    optimalPath::Any
    overallCost::Any
    netOverallRevenues::Any
    error::Any
end

struct states
    seg::Any
end

struct optimalStage
    stage::Any
    optimalValue::Any
    price::Any
    #currentState::Any
    #nextState::Any
    currentSOC::Any
    nextSOC::Any
    charge::Any
    discharge::Any
    toGrid::Any
    deg::Any
    PV::Any
    netRev::Any
    batteryCost::Any
    bat::Any
    sh_en::Any
    ld::Any
    in::Any
end

struct Results_dp_no_deg
    Power_prices::Any
    pv_prod::Any
    load::Any
    incentivo::Any
    BESS_charge::Any
    BESS_discharge::Any
    PV_grid::Any
    charge_from_PV::Any
    shared_energy::Any
    gain::Any
    revenues_shared_energy::Any
    val::Any
    optimalValueStates::Any
    optimalfromState::Any
    optimalPath::Any
    netOverallRevenues::Any
    error::Any
end

struct optimalStage_no_deg
    stage::Any
    optimalValue::Any
    price::Any
    #currentState::Any
    #nextState::Any
    currentSOC::Any
    nextSOC::Any
    charge::Any
    discharge::Any
    toGrid::Any
    #deg::Any
    PV::Any
    netRev::Any
    #batteryCost::Any
    #bat::Any
    sh_en::Any
    ld::Any
    in::Any
end



#show(io::IO,x::optimalStage) = print(io, "Stage:",x.stage," -> optimal Value = ",x.optimalValue," ,current State = ",x.currentState," ,next State = ",x.nextState," ,current SOC = ",x.currentSOC," ,next SOC = ",x.nextSOC," ,action = ",x.action, " , net gain =",x.gain, "battery Cost =",x.batteryCost)
