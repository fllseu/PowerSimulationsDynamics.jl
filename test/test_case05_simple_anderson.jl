"""
Case 5:
This case study a three bus system with 2 machines (Simple Anderson-Fouad: 4th order model) and an infinite source.
The fault drop the connection between buses 1 and 3, eliminating the direct connection between the infinite source
and the generator located in bus 3.
"""

##################################################
############### LOAD DATA ########################
##################################################

include(joinpath(dirname(@__FILE__), "data_tests/test05.jl"))

##################################################
############### SOLVE PROBLEM ####################
##################################################

#time span
tspan = (0.0, 200.0);
#Define Fault: Change of YBus
Ybus_change = ThreePhaseFault(
    1.0, #change at t = 1.0
    Ybus_fault,
) #New YBus

path = (joinpath(pwd(), "test-05"))
!isdir(path) && mkdir(path)
try
    #Define Simulation Problem
    sim = Simulation!(
        path,
        threebus_sys, #system
        tspan, #time span
        Ybus_change, #Type of Fault
    )

    small_sig = small_signal_analysis(sim)

    #Solve problem in equilibrium
    execute!(sim, IDA(), dtmax = 0.02)

    #Obtain data for angles
    series = get_state_series(sim, ("generator-102-1", :δ))

    diff = [0.0]
    res = get_init_values_for_comparison(sim)
    for (k, v) in test05_x0_init
        diff[1] += LinearAlgebra.norm(res[k] - v)
    end
    @test (diff[1] < 1e-3)
    @test sim.solution.retcode == :Success
    @test small_sig.stable
finally
    @info("removing test files")
    rm(path, force = true, recursive = true)
end
