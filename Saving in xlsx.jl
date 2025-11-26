# EXCEL SAVINGS
using DataFrames
using XLSX

function data_saving(InputParameters::InputParam,ResultsDP::Results_dp)

    @unpack (NYears, NHoursStep, NStates, Big)= InputParameters;
    @unpack (energy_Capacity, Eff_charge, NFull, grid_Capacity, PV_max) = Battery;
    @unpack (optimalPath) = ResultsDP;

    nameF= "REC $NYears years, eff=$Eff_charge, $energy_Capacity kWh, $PV_max PV, $grid_Capacity M2"
    mkdir(nameF)
    cd(nameF)
    main=pwd()

    optimalSOC=zeros(NSteps+1);
    optimalChargeBattery=zeros(NSteps+1);
    optimalDischargeBattery=zeros(NSteps+1);
    optimalDischargeGrid=zeros(NSteps+1);
    optimalDegradation=zeros(NSteps+1);
    optimalSharedEnergy = zeros(NSteps+1);
    PV=zeros(NSteps+1);
    LOAD = zeros(NSteps+1);
    incentives = zeros(NSteps+1);
    price=zeros(NSteps+1);
    cost=zeros(NSteps+1);
    degradationCost=zeros(NSteps+1);
    netRevenues=zeros(NSteps+1);

    BESS_PV_rev = zeros(NSteps+1);
    SE_rev = zeros(NSteps+1);

    for t=1:NSteps
        optimalSOC[t]=optimalPath[t].currentSOC
        optimalChargeBattery[t]=optimalPath[t].charge
        optimalDischargeBattery[t]=optimalPath[t].discharge
        optimalDischargeGrid[t]=optimalPath[t].toGrid           #quello che il PV vende in rete
        optimalDegradation[t]=optimalPath[t].deg
        optimalSharedEnergy[t]= optimalPath[t].sh_en
        PV[t]=optimalPath[t].PV
        LOAD[t] = optimalPath[t].ld
        incentives[t] = optimalPath[t].in
        price[t]=optimalPath[t].price
        cost[t]=optimalPath[t].bat
        degradationCost[t]=optimalPath[t].batteryCost
        netRevenues[t]=optimalPath[t].netRev
        BESS_PV_rev[t] = price[t].*(optimalDischargeBattery[t].+optimalDischargeGrid[t])
        SE_rev[t]= incentives[t].*optimalSharedEnergy[t]
    end

    optimalSOC[end]=optimalPath[end].nextSOC;

    for t=1:NStages
        table=DataFrame()
        table[!,"Steps"]= Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])
        table[!,"Energy price €/kWh"] = price[Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])]
        table[!,"Incentivi €/kWh"] = incentives[Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])]
        table[!,"SOC kWh"] = optimalSOC[Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])]
        table[!,"Degradation kWh"] = optimalDegradation[Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])]
        table[!,"Charge Battery kW"] = optimalChargeBattery[Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])]
        table[!,"Discharge Battery kW"]= optimalDischargeBattery[Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])]
        table[!,"PV to Grid kW"] = optimalDischargeGrid[Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])]
        table[!,"Shared Energy kW"] = optimalSharedEnergy[Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])]
        table[!,"PV production kW"] = PV[Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])]
        table[!,"Carico kW"] = LOAD[Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])]
        
        table[!,"Revenues from BESS+PV €"] = BESS_PV_rev[Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])]
        table[!,"Revenues from Shared Energy €"] = SE_rev[Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])]
        table[!,"Cost battery €/kWh"] = cost[Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])]
        table[!,"Revamping Cost €"] = degradationCost[Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])]
        table[!,"Net Revenues €"] = netRevenues[Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])]

        XLSX.writetable("Stage $t.xlsx", overwrite=true,
        results = (collect(DataFrames.eachcol(table)),DataFrames.names(table))
        )

    end

    bess_pv_revenues = zeros(NStages);
    se_revenues = zeros(NStages);
    net_revenues=zeros(NStages);
    Battery_cost=zeros(NStages);
    bat_deg =zeros(NStages);

    for t=1:NStages
        bat_deg[t]= sum(optimalDegradation[Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])])
        bess_pv_revenues[t] = sum(BESS_PV_rev[Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])])
        se_revenues[t] =sum(SE_rev[Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])])
        Battery_cost[t]=sum(degradationCost[Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])])
        net_revenues[t]=sum(netRevenues[Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])])
    end

    table1=DataFrame()
    table1[!,"Stage"]=1:NStages
    table1[!,"Battery degradation kWh"] =bat_deg[:]
    table1[!,"BESS+PV revenues €"] = bess_pv_revenues[:]
    table1[!,"Shared Energy revenues €"] = se_revenues[:]
    table1[!,"Cost replacement €"]=Battery_cost[:]
    table1[!,"Net revenues €"]=net_revenues[:]

    XLSX.writetable("Final values $energy_Capacity.xlsx", overwrite=true,
        results = (collect(DataFrames.eachcol(table1)),DataFrames.names(table1))
    )
    cd(main)


end


function data_saving_no_deg(InputParameters::InputParam,Results_no_Deg::Results_dp_no_deg)

    @unpack (NYears, NHoursStep, NStates, Big)= InputParameters;
    @unpack (energy_Capacity, Eff_charge, NFull, grid_Capacity, PV_max) = Battery;
    @unpack (optimalPath) = Results_no_Deg;

    nameF= "REC $NYears years, eff=$Eff_charge, $energy_Capacity kWh, $PV_max PV, $grid_Capacity m2_kW NO DEG"
    mkdir(nameF)
    cd(nameF)
    main=pwd()

    optimalSOC=zeros(NSteps+1);
    optimalChargeBattery=zeros(NSteps+1);
    optimalDischargeBattery=zeros(NSteps+1);
    optimalDischargeGrid=zeros(NSteps+1);
    optimalSharedEnergy = zeros(NSteps+1);
    PV=zeros(NSteps+1);
    LOAD = zeros(NSteps+1);
    incentives = zeros(NSteps+1);
    price=zeros(NSteps+1);
    netRevenues=zeros(NSteps+1);

    BESS_PV_rev = zeros(NSteps+1);
    SE_rev = zeros(NSteps+1);

    for t=1:NSteps
        optimalSOC[t]=optimalPath[t].currentSOC
        optimalChargeBattery[t]=optimalPath[t].charge
        optimalDischargeBattery[t]=optimalPath[t].discharge
        optimalDischargeGrid[t]=optimalPath[t].toGrid           #quello che il PV vende in rete
        optimalSharedEnergy[t]= optimalPath[t].sh_en
        PV[t]=optimalPath[t].PV
        LOAD[t] = optimalPath[t].ld
        incentives[t] = optimalPath[t].in
        price[t]=optimalPath[t].price
        netRevenues[t]=optimalPath[t].netRev
        BESS_PV_rev[t] = price[t].*(optimalDischargeBattery[t].+optimalDischargeGrid[t])
        SE_rev[t]= incentives[t].*optimalSharedEnergy[t]
    end

    optimalSOC[end]=optimalPath[end].nextSOC;

    for t=1:NStages
        table=DataFrame()
        table[!,"Steps"]= Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])
        table[!,"Energy price €/kWh"] = price[Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])]
        table[!,"Incentivi €/kWh"] = incentives[Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])]
        table[!,"SOC kWh"] = optimalSOC[Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])]
        table[!,"Charge Battery kW"] = optimalChargeBattery[Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])]
        table[!,"Discharge Battery kW"]= optimalDischargeBattery[Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])]
        table[!,"PV to Grid kW"] = optimalDischargeGrid[Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])]
        table[!,"Shared Energy kW"] = optimalSharedEnergy[Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])]
        table[!,"PV production kW"] = PV[Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])]
        table[!,"Carico kW"] = LOAD[Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])]
        table[!,"Revenues from BESS+PV €"] = BESS_PV_rev[Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])]
        table[!,"Revenues from Shared Energy €"] = SE_rev[Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])]
        table[!,"Net Revenues €"] = netRevenues[Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])]

        XLSX.writetable("Stage $t.xlsx", overwrite=true,
        results = (collect(DataFrames.eachcol(table)),DataFrames.names(table))
        )

    end

    net_revenues=zeros(NStages);
    bess_pv_revenues = zeros(NStages);
    se_revenues = zeros(NStages);
    for t=1:NStages
        bess_pv_revenues[t] = sum(BESS_PV_rev[Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])])
        se_revenues[t] = sum(SE_rev[Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])])
        net_revenues[t]=sum(netRevenues[Int(Steps_revamping[t])+1:Int(Steps_revamping[t+1])])
    end

    table1=DataFrame()
    table1[!,"Stage"]=1:NStages
    table1[!,"BESS+PV revenues €"] = bess_pv_revenues[:]
    table1[!,"Shared Energy revenues €"] = se_revenues[:]
    table1[!,"Net revenues €"]=net_revenues[:]

    XLSX.writetable("Final values $energy_Capacity.xlsx", overwrite=true,
        results = (collect(DataFrames.eachcol(table1)),DataFrames.names(table1))
    )

    cd(main)



end






