# SPDX-License-Identifier: LGPL-3.0-only
using Serialization, Sockets

const PORT_RANGE = 24721:24999
const IN_CHANNEL_LENGTH = 10000

struct PostException
    message::String
end

struct PostOffice
    outsocket::UDPSocket
    postcode::PostCode
    socket::UDPSocket
    intask
    inchannel
end
PostOffice() = PostOffice(UDPSocket(), allocate_postcode()...)

postcode(post::PostOffice) = post.postcode
addr(post::PostOffice) = Addr(postcode(post), 0)

function allocate_postcode()
    socket = UDPSocket()
    ipaddr = Sockets.getipaddr()
    for port in PORT_RANGE
        postcode = "$(ipaddr):$port"
        bound = bind(socket, ipaddr, port)
        bound || continue
        @debug "Bound to $postcode"
        inchannel = Channel(IN_CHANNEL_LENGTH)
        intask = Threads.@spawn arrivals(socket, inchannel)
        return postcode, socket, intask, inchannel
    end
    throw(PostException("No available port found for a Post Office"))
end

function shutdown!(post::PostOffice)
    close(post.socket)
end

@inline function getmessage(post::PostOffice)
    return isready(post.inchannel) ? take!(post.inchannel) : nothing
end

function arrivals(socket::UDPSocket, channel::Channel)
    try
        while true
            rawmessage = recv(socket)
            stream = IOBuffer(rawmessage)
            msg = deserialize(stream)
            @debug "Postoffice got message $msg"
            put!(channel, msg)
        end
    catch e
        if !(e isa EOFError)
            @info "Exception in arrivals", e
        end
    end
end

@inline function send(post::PostOffice, message)
    @debug "PostOffice delivery at $(postcode(post)): $message"
    parts = split(postcode(target(message)), ":")
    ip = parse(IPAddr, parts[1])
    port = parse(UInt16, parts[2])
    io = IOBuffer()
    serialize(io, message)
    Sockets.send(post.outsocket, ip, port, take!(io))
end