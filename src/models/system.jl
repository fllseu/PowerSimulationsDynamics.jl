function update_global_vars!(inputs::SimulationInputs, x::AbstractArray)
    index = get_global_vars(inputs)[:ω_sys_index]
    index == 0 && return
    #TO DO: Make it general for cases when ω is not a state (droop)!
    get_global_vars(inputs)[:ω_sys] = x[index]
    return
end

function system!(out::Vector{<:Real}, dx, x, inputs::SimulationInputs, t::Float64)
    sys = get_system(inputs)
    I_injections_r = get_aux_arrays(inputs)[1]
    I_injections_i = get_aux_arrays(inputs)[2]
    injection_ode = get_aux_arrays(inputs)[3]
    branches_ode = get_aux_arrays(inputs)[4]

    #Index Setup
    bus_size = get_bus_count(inputs)
    bus_vars_count = 2 * bus_size
    bus_range = 1:bus_vars_count
    injection_start = get_injection_pointer(inputs)
    injection_count = 1
    branches_start = get_branches_pointer(inputs)
    branches_count = 1
    update_global_vars!(inputs, x)

    #Network quantities
    V_r = @view x[1:bus_size]
    V_i = @view x[(bus_size + 1):bus_vars_count]
    Sbase = PSY.get_base_power(sys)
    fill!(I_injections_r, 0.0)
    fill!(I_injections_i, 0.0)

    for d in get_injectors_data(inputs)
        dynamic_device = PSY.get_dynamic_injector(d)
        bus_n = PSY.get_number(PSY.get_bus(d))
        bus_ix = get_lookup(inputs)[bus_n]
        n_states = PSY.get_n_states(dynamic_device)
        ix_range = range(injection_start, length = n_states)
        ode_range = range(injection_count, length = n_states)
        injection_count = injection_count + n_states
        injection_start = injection_start + n_states
        device!(
            x,
            injection_ode,
            view(V_r, bus_ix),
            view(V_i, bus_ix),
            view(I_injections_r, bus_ix),
            view(I_injections_i, bus_ix),
            ix_range,
            ode_range,
            dynamic_device,
            inputs,
        )
        out[ix_range] = injection_ode[ode_range] - dx[ix_range]
    end

    for d in PSY.get_components(PSY.ElectricLoad, sys)
        bus_n = PSY.get_number(PSY.get_bus(d))
        bus_ix = get_lookup(inputs)[bus_n]
        device!(
            view(V_r, bus_ix),
            view(V_i, bus_ix),
            view(I_injections_r, bus_ix),
            view(I_injections_i, bus_ix),
            d,
            inputs,
        )
    end

    for d in PSY.get_components(PSY.Source, sys)
        bus_n = PSY.get_number(PSY.get_bus(d))
        bus_ix = get_lookup(inputs)[bus_n]
        device!(
            view(V_r, bus_ix),
            view(V_i, bus_ix),
            view(I_injections_r, bus_ix),
            view(I_injections_i, bus_ix),
            d,
            inputs,
        )
    end

    if get_dyn_lines(inputs)
        dyn_branches = PSY.get_components(PSY.DynamicBranch, sys)
        for br in dyn_branches
            arc = PSY.get_arc(br)
            n_states = PSY.get_n_states(br)
            from_bus_number = PSY.get_number(arc.from)
            to_bus_number = PSY.get_number(arc.to)
            bus_ix_from = get_lookup(inputs)[from_bus_number]
            bus_ix_to = get_lookup(inputs)[to_bus_number]
            ix_range = range(branches_start, length = n_states)
            ode_range = range(branches_count, length = n_states)
            branches_count = branches_count + n_states
            branch!(
                x,
                dx,
                branches_ode,
                #Get Voltage data
                view(V_r, bus_ix_from),
                view(V_i, bus_ix_from),
                view(V_r, bus_ix_to),
                view(V_i, bus_ix_to),
                #Get Current data
                view(I_injections_r, bus_ix_from),
                view(I_injections_i, bus_ix_from),
                view(I_injections_r, bus_ix_to),
                view(I_injections_i, bus_ix_to),
                ix_range,
                ode_range,
                br,
                inputs,
            )
            out[ix_range] = branches_ode[ode_range] - dx[ix_range]
        end
    end

    kirchoff_laws!(inputs, V_r, V_i, I_injections_r, I_injections_i, dx)
    out[bus_range] = get_aux_arrays(inputs)[6]
end
