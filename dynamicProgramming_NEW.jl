function DP(                                                                                                   # Ora conosco per ogni settimana i valori di inflow e prezzo (calcolati con il modello di Markov) - risolvo il problema come "DETERMINISTICO"
  InputParameters::InputParam,
  Battery::BatteryParam,
  state_variables::states,
  runMode::runModeParam,
  Power_prices,
  PV_cont,
  Battery_prices,
  tariffa_premio, 
  tariffa_PV,
  load_kW,
  )

  @unpack (NYears, NHoursStep, NStates, Big)= InputParameters;
  @unpack (grid_Capacity, min_SOC, energy_Capacity, power_Capacity, Eff_charge, Eff_discharge, NFull, DoD, NCycles) = Battery;      
  @unpack (productionPV, battery_replacement) = runMode
  @unpack (seg) = state_variables;

  incentivo = tariffa_premio.+tariffa_PV;

  battery_cost=zeros(NSteps);
  pv_prod = zeros(NSteps);
  gridMax = grid_Capacity;

  if battery_replacement                                           # if true -> evaluating with cell -replacement , give the cost
    for j=1:NStages
      battery_cost[Int(Steps_revamping[j])+1:Int(Steps_revamping[j+1])] .= Battery_prices[j]
    end
  end

  if productionPV
    pv_prod = PV_cont[1:NSteps]
  end

  optimalValueStates = zeros(NSteps+1,NStates)                                 # Final Optimal value for each State of the t-stage -> considers the max among all combinations ex: ValueStates[23,5] = 124€ -> if we are in day 23 at stage 5, the value I would have is of 124€
  optimalValueStates[end,:] = seg * Battery_prices[NStages+1]                  # Initialize the Values of NStages+1 (starting point DP)
  optimalfromState = zeros(NSteps,NStates)                                     # Indicates the optimal state from which we are coming from ex: fromState[23,5] =2 -> if we are at day 23 in state 5 (0% of energy), we are comiing from state 2 in day 24
  val = zeros(NSteps,NStates,NStates)                                          # Per ogni stato del sistema, calcolo tutte le transizioni e poi ne prendo la massima                                                             

  # VECTORS FOR EVERY POSSIBLE COMBINATION
  BESS_charge = zeros(NSteps,NStates,NStates)                                  # IDEAL/THEORETIC power needed to charge the battery from one state to another
  BESS_discharge = zeros(NSteps,NStates,NStates)                               # IDEAL/THEORETIC power needed to discharge the battery from one state to another
  
  PV_grid = zeros(NSteps,NStates,NStates)                                      # actual power absorbed by the Battery from the PV system
  charge_from_PV =zeros(NSteps,NStates,NStates)                                # remaining power from PV (after charging the battery) discharged to the grid

  degradation = zeros(NSteps,NStates,NStates)                                  # accounts for the % of battery degradated beacuse of its use (quadratic formulation as function of the state of the system)
  shared_energy = zeros(NSteps,NStates,NStates)
  optimalPath = []

  gain = zeros(NSteps,NStates,NStates)
  revenues_shared_energy = zeros(NSteps,NStates,NStates)
  replacementCost = zeros(NSteps,NStates,NStates)

  @timeit to "Solve dynamic programming" begin

    for t = NSteps:-1:1                                                        # Calcolo per ogni ora partendo dall'ultimo step 
      
      soc_start = 0
      soc_final = 0

      println("STEP:", t, " battery cost:",battery_cost[t])

      for iState=1:NStates                                                      # Considero gg=365gg*24h*2 tutti i possibili stati

        soc_start = seg[iState]

          for jState=1:NStates                                                  # Considero tutti gli stati allo stage successivo

            #CALCULATES THE CHARGE/DISCHARGE FROM ONE STAGE TO ANOTHER CONSIDERING ALL POSSIBLE STATE TRANSITIONS PER EACH STAGE

            soc_final = seg[jState]
            penalty_Export = 0
            penalty_SOC = 0
            penalty_PV = 0

            if soc_final > soc_start          #CHARGING PHASE
                
                BESS_charge[t,iState,jState] = abs((soc_final-soc_start)/(NHoursStep*Eff_charge))         #calculates how much power is needed to charge the battery from one state to another
                BESS_discharge[t,iState,jState] = 0                                                       # since we are in Charging Phase, we cannot discharge at the same time

                degradation[t,iState,jState] = abs(soc_start^2/energy_Capacity^2-soc_final^2/energy_Capacity^2+2/energy_Capacity*(soc_final-soc_start))/(2*NFull)*energy_Capacity   #Evaluates the corresponding degrdation in kWh/MWh (depends on the size of the system)
                #degradation[t,iState,jState] =0.5*energy_Capacity*abs(1/NCycles[iState]-1/NCycles[jState])

                # INFEASIBILITIES ON MAXIMUM POWER FOR CHARGING
                # if true add penalty (cannot "do" this transition), otherwise leave and go on

                if BESS_charge[t,iState,jState]>power_Capacity
                  penalty_SOC = Big
                else
                  # INFEASIBILITY ON CHARGING FROM PV
                  # if the power required for charging the battery is higher than PV_power available, the probem is infeasibe (BESS cannot charge from the grid) 
                  # otherwise absorb power from PV and sell the rest to the grid
                
                  if BESS_charge[t,iState,jState] > pv_prod[t]                 
                    penalty_PV = Big
                  else
                    charge_from_PV[t,iState,jState] = BESS_charge[t,iState,jState]
                    PV_grid[t,iState,jState] = pv_prod[t]-charge_from_PV[t,iState,jState]

                      if BESS_discharge[t,iState,jState]+PV_grid[t,iState,jState] > gridMax
                        penalty_Export = Big
                      end

                  end

                end

            elseif soc_final < soc_start       #DISCHARGING PHASE
              
              BESS_charge[t,iState,jState] = 0
              BESS_discharge[t,iState,jState] = abs((soc_final-soc_start)*Eff_discharge/NHoursStep)       #discharge from battery       
              degradation[t,iState,jState] = abs(soc_start^2/energy_Capacity^2-soc_final^2/energy_Capacity^2+2/energy_Capacity*(soc_final-soc_start))/(2*NFull)*energy_Capacity

              #degradation[t,iState,jState] =abs((1-soc_start/energy_capacity)^1.5-(1-soc_final/energy_CXapacity)^1.5)*energy_capacity/(2*NFull)
              PV_grid[t,iState,jState]=pv_prod[t]

              if BESS_discharge[t,iState,jState]>power_Capacity
                penalty_SOC = Big
              else
                if BESS_discharge[t,iState,jState]+PV_grid[t] > gridMax
                  penalty_Export = Big
                end
              end

            else                               #IDLING PHASE -> can only sell power from PV to the grid (if any)
                
              BESS_charge[t,iState,jState] = 0
              BESS_discharge[t,iState,jState] = 0
              degradation[t,iState,jState] = 0
              PV_grid[t,iState,jState] = pv_prod[t]

              if PV_grid[t,iState,jState] > gridMax #se vi è un limite su potenza massima nella rete e la potenza da PV è maggiore della capacità di rete)
                penalty_Export = Big
              end
      
            end

            shared_energy[t,iState,jState] = min(load_kW[t],BESS_discharge[t,iState,jState]+PV_grid[t,iState,jState])

            val[t,iState,jState] = Power_prices[t]*NHoursStep*(BESS_discharge[t,iState,jState]+PV_grid[t,iState,jState]) - degradation[t,iState,jState]*battery_cost[t] + incentivo[t]*shared_energy[t,iState,jState]*NHoursStep -penalty_Export -penalty_SOC - penalty_PV + optimalValueStates[t+1,jState]      #/10E5
            gain[t,iState,jState] = Power_prices[t]*NHoursStep*(BESS_discharge[t,iState,jState]+PV_grid[t,iState,jState])
            revenues_shared_energy[t,iState,jState]= incentivo[t]*shared_energy[t,iState,jState]*NHoursStep
            replacementCost[t,iState,jState] = degradation[t,iState,jState]*battery_cost[t]    

          end # end jStates=1:5

        optimalValueStates[t,iState] = findmax(val[t,iState,:])[1]             # Trovo il massimo del Valore funzione obiettivo : transizioni + valore stato precedente 
        optimalfromState[t,iState] = findmax(val[t,iState,:])[2]               # Mi dice da quale stato al giorno precedente (o futuro) arrivo

        println("Optimal Val at stage t: $t and state x $iState: ",optimalValueStates[t,iState], " coming from state: ",optimalfromState[t,iState])
        println()

      end

    end   # end Steps

    # RACCOLGO I RISULTATI DEL PERCORSO MIGLIORE

    a = findmax(optimalValueStates[1,:])[2]            # Mi inidica in quale stato per NStage=1 ho il massimo valore
    netOverallRevenues = 0 
    overallCost = 0

    let startingFrom =a, comingFrom=0
      for t=1:NSteps
        
        comingFrom = Int(optimalfromState[t,startingFrom])                        # Inidca da quale stato presedente sono arrivato
      
        #optValue = findmax(optimalValueStates[t,startingFrom])[1]
        optValue = optimalValueStates[t,startingFrom]
        charge_bat = charge_from_PV[t,startingFrom,comingFrom]
        dis_bat = BESS_discharge[t,startingFrom,comingFrom]
        pv_grid = PV_grid[t,startingFrom,comingFrom]
        degMWh= degradation[t,startingFrom,comingFrom]
        sh_en = shared_energy[t,startingFrom,comingFrom]
        pv = pv_prod[t]
        ld = load_kW[t]
        in = incentivo[t]
        price = Power_prices[t]
        bat=battery_cost[t]
        

        net_revenues = gain[t,startingFrom,comingFrom] + revenues_shared_energy[t,startingFrom,comingFrom] - replacementCost[t,startingFrom,comingFrom]
        batCost = replacementCost[t,startingFrom,comingFrom]  

        overallCost = overallCost + batCost
        netOverallRevenues = netOverallRevenues + net_revenues

        push!(optimalPath,saveOptimalValues(t, optValue, price, startingFrom, comingFrom, seg, charge_bat, dis_bat, pv_grid, degMWh, pv, net_revenues, batCost, bat, sh_en,ld,in))
        
        startingFrom=comingFrom

      end
    end
    
    error = []
    for t=1:NSteps
      if optimalPath[t].charge> energy_Capacity
        push!(error,optimalPath[t])
      end
    end

  end

  return Results_dp(
    Power_prices,
    battery_cost,
    pv_prod,
    load_kW,
    incentivo,
    BESS_charge,
    BESS_discharge,
    PV_grid,
    charge_from_PV,
    degradation,
    shared_energy,
    gain,
    revenues_shared_energy,
    replacementCost,
    val,
    optimalValueStates,
    optimalfromState,
    optimalPath,
    overallCost,
    netOverallRevenues,
    error,
   )

end


#show(io::IO,x::optimalStage) = print(io,"Stage:",x.stage," -> opVal = ",x.optimalValue," price = ",x.price," curSOC = ",x.currentSOC,", nextSOC = ",x.nextSOC,", charge = ",x.charge, ", discharge = ",x.discharge ,", toGrid = ",x.toGrid,", PV = ", x.PV ,", netRevenues = ",x.netRev, ", batCost = ",x.batteryCost)

function saveOptimalValues(stage::Int64,optimalValue::Float64,price::Float64, curSt::Int64, nextSt::Int64, seg::Any, charge::Float64,discharge::Float64, toGrid::Float64, deg::Float64, PV::Float64, netRev::Float64 , batteryCost::Float64 , bat::Float64, sh_en::Float64,ld::Float64,in::Float64)
  optimalStage(stage, optimalValue, price, seg[curSt], seg[nextSt], charge, discharge, toGrid,deg, PV,netRev, batteryCost, bat, sh_en,ld,in)
end


