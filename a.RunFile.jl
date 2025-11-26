#RUN FILE

# Calls the Packages used for the optimization problem
using Printf
using MathOptInterface
using JLD
using TimerOutputs
using DataFrames
using XLSX
using Parameters
using Dates
using CSV
using Base

import Base.show

# Calls the other Julia files
include("Structures.jl")
include("SetInputParameters.jl")
include("dynamicProgramming_NEW.jl")
include("Saving in xlsx.jl")
include("dynamicProgramming_no_deg.jl")

date = string(today())

# PREPARE INPUT DATA
to = TimerOutput()

@timeit to "Set input data" begin

  #Set run case - indirizzi delle cartelle di input ed output
  case = set_runCase()
  @unpack (DataPath,InputPath,ResultPath,CaseName) = case;

  # Set run mode (how and what to run) and Input parameters
  runMode = read_runMode_file()
  @unpack (dynamicProgramming, excel_savings, sud, centro, nord,battery_replacement) = runMode
   InputParameters = set_parameters(runMode, case)
  @unpack (NYears, NHoursStep, NStates, Big)= InputParameters;

  # Upload battery's characteristics
  Battery = set_battery_system(runMode, case);
  @unpack (grid_Capacity,min_SOC, energy_Capacity, power_Capacity, Eff_charge, Eff_discharge, NFull, PV_max) = Battery; 

  # Read cost fo ceel replacements from a file [€/KWh] oppure [€/MWh] - ATTENZIONE ALLE UNITA' DI MISURA!
  Battery_prices = read_csv("Battery_decreasing_prices_mid_kWh.csv",case.DataPath)

  #Read power prices for 10 years - ATTENZIONE ALLE UNITA' DI MISURA!! 
  #N.B: quando cambio la zona (nord,sud,centro) devo cambiare anche i prezzi ZONALI
  Pp14 = read_csv("prices_2014_NORD_kWh.csv", case.DataPath);
  Pp15 = read_csv("prices_2015_NORD_kWh.csv", case.DataPath);
  Pp16 = read_csv("prices_2016_NORD_kWh.csv", case.DataPath);
  Pp17 = read_csv("prices_2017_NORD_kWh.csv", case.DataPath)
  Pp18 = read_csv("prices_2018_NORD_kWh.csv", case.DataPath);
  Pp19 = read_csv("prices_2019_NORD_kWh.csv", case.DataPath);
  Pp20 = read_csv("prices_2020_NORD_kWh.csv", case.DataPath);
  Pp21 = read_csv("prices_2021_NORD_kWh.csv", case.DataPath);
  Pp22 = read_csv("prices_2022_NORD_kWh.csv", case.DataPath);
  Pp23 = read_csv("prices_2023_NORD_kWh.csv", case.DataPath);
  
  Power_prices = vcat(Pp14,Pp15,Pp16,Pp17,Pp18,Pp19,Pp20,Pp21,Pp22,Pp23); 
  NSteps = length(Power_prices)
  #Steps_revamping = [0 8688 17520 26208 35040 43728 52560 61392 70080 78912 87600 96432 105120 113952 122640 131472 140160 148992 157680 166512 175200]   #Preso dalla liste excel modoEenergy  start 1st January 2026 - da aggiungere +1 negli altri file
  Steps_revamping = read_csv("Steps revamping.csv", case.DataPath);
  NStages = Int(length(Steps_revamping))-1

  PV14 = read_csv("PV-Trento-2014.csv",case.DataPath);           
  PV15 = read_csv("PV-Trento-2015.csv",case.DataPath);     
  PV16 = read_csv("PV-Trento-2016.csv",case.DataPath);     
  PV17 = read_csv("PV-Trento-2017.csv",case.DataPath);     
  PV18 = read_csv("PV-Trento-2018.csv",case.DataPath);     
  PV19 = read_csv("PV-Trento-2019.csv",case.DataPath);  
  PV20 = read_csv("PV-Trento-2020.csv",case.DataPath);     
  PV21 = read_csv("PV-Trento-2021.csv",case.DataPath);     
  PV22 = read_csv("PV-Trento-2022.csv",case.DataPath);     
  PV23 = read_csv("PV-Trento-2023.csv",case.DataPath);           

  PV_tot = vcat(PV14,PV15,PV16,PV17,PV18,PV19,PV20,PV21,PV22,PV23);        # I valori nel file sono espressi in p.u. - vanno poi moltiplicati per la capacità nominale dell'impianto        
  PV_cont = [];
  for iYear=1:NYears
    for iStep=1:NSteps
      push!(PV_cont,PV_tot[iStep]*PV_max)
    end
  end

  carico = read_csv("Load_kW_200_membri.csv", case.DataPath);        # I valori sono espressi in kW e per cambiare numero di membri bisogna cambiare il file
  load_kW = [];
  for iYear=1:NYears
    for iStep=1:Int(NSteps/NYears)
      push!(load_kW,carico[iStep])
    end
  end

  # DEFINE STATE VARIABLES - STATE OF CHARGES SOC [MWh]
  state_variables = define_state_variables(InputParameters, Battery)

  #CALCOLO INCENTIVI
  tariffa_premio, tariffa_PV = calculate_incentives(Power_prices,grid_Capacity,PV_cont,sud,centro,nord);
 
end

# DYNAMIC PROGRAMMING
if dynamicProgramming
    if battery_replacement
      ResultsDP = DP(InputParameters, Battery, state_variables, runMode, Power_prices, PV_cont, Battery_prices, tariffa_premio, tariffa_PV, load_kW)   #configurations
    else
      Results_no_Deg = DP_no_deg(InputParameters, Battery, state_variables, runMode, Power_prices, PV_cont, tariffa_premio, tariffa_PV, load_kW)
    end
else
    println("Solved without dynamic programming.")
end

# SAVE OTIMAL-PATH DATA IN EXCEL FILES
if excel_savings
  cartella = "C:\\Users\\Utente\\Desktop\\GORA SEST\\Results GORA REC"
  cd(cartella)
  if battery_replacement
    data_saving(InputParameters,ResultsDP)
  else
    data_saving_no_deg(InputParameters,Results_no_Deg)
  end
  println("Results saved")
else
  println("Solved without saving results in xlsx format.")
end



print(to)



