# SPDX-License-Identifier: LGPL-3.0-only

import Base.getindex, Base.get

abstract type SchedulerPlugin end

# Plugin interface
localroutes(plugin::SchedulerPlugin) = nothing
infotonhandler(plugin::SchedulerPlugin) = nothing
symbol(plugin::SchedulerPlugin) = :nothing
setup!(plugin::SchedulerPlugin, scheduler) = nothing
shutdown!(plugin::SchedulerPlugin) = nothing

struct LocalRoute
    routerfn::Function
    plugin::SchedulerPlugin
end

struct InfotonHandler
    handlerfn::Function
    plugin::SchedulerPlugin
end

struct Plugins
    plugins::Dict{Symbol, SchedulerPlugin}
    localroutes::Array{LocalRoute}
    infotonhandlers::Array{InfotonHandler}
end

function Plugins(plugins::AbstractArray)
    return Plugins(plugin_dict(plugins), localroutes(plugins), infotonhandlers(plugins))
end

plugin_dict(plugins) = Dict{Symbol, SchedulerPlugin}([(symbol(plugin), plugin) for plugin in plugins])
getindex(p::Plugins, idx) = getindex(p.plugins, idx)
get(p::Plugins, idx, def) = get(p.plugins, idx, def)

localroutes(plugins::AbstractArray) = [LocalRoute(localroutes(plugin), plugin) for plugin in plugins if !isnothing(localroutes(plugin))]
infotonhandlers(plugins::AbstractArray) = [InfotonHandler(infotonhandler(plugin), plugin) for plugin in plugins if !isnothing(infotonhandler(plugin))]

@inline function route_locally(plugins::Plugins, scheduler::AbstractActorScheduler, message::AbstractMsg)
    for route in plugins.localroutes
        if route.routerfn(route.plugin, scheduler, message)
            return true
        end
    end
    return false
    
end

@inline function apply_infoton(plugins::Plugins, scheduler::AbstractActorScheduler, targetactor::AbstractActor, message::AbstractMsg)
    for handler in plugins.infotonhandlers
        handler.handlerfn(handler.plugin, scheduler, targetactor, message)
    end
    return nothing
end

setup!(plugins::Plugins, scheduler) = for plugin in values(plugins.plugins) setup!(plugin, scheduler) end
shutdown!(plugins::Plugins) = shutdown!.(values(plugins.plugins))