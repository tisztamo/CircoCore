module Debug

export Run, Step, Stop, MsgStats

struct Run a::UInt8 end 
struct Step a::UInt8 end 
struct Stop a::UInt8 end

include("msgstats.jl")

end