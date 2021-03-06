# SPDX-License-Identifier: LGPL-3.0-only
import Base.show

"""
    NameQuery(name::String) <: Request

A query that can be sent to a remote scheduler for querying its local registry.
"""
struct NameQuery <: Request
    name::String
    token::Token
    NameQuery(name, token) = new(name, token)
    NameQuery(name) = new(name, Token())
end

struct NameResponse <: Response
    query::NameQuery
    handler::Union{Addr, Nothing}
    token::Token
end

struct LocalRegistry
    register::Dict{String, Addr}
    LocalRegistry() = new(Dict())
end

struct RegisteredException <: Exception
    name::String
end
Base.show(io::IO, e::RegisteredException) = print(io, "name '", e.name, "' already registered")

function registername(service::LocalRegistry, name::String, handler::Addr)
    haskey(service.register, name) && throw(RegisteredException(name))
    service.register[name] = handler
    return true
end

function getname(registry::LocalRegistry, name::String)::Union{Addr, Nothing}
    get(registry.register, name, nothing)
end

function handle_special!(scheduler::AbstractActorScheduler, message::Msg{NameQuery})
    @debug "Registry handle_special! $message"
    send(scheduler.postoffice, Msg(
            addr(scheduler),
            sender(message),
            NameResponse(body(message), getname(scheduler.registry, body(message).name), body(message).token),
            Infoton(nullpos)
        ))
end