import Base: isless

isless(atomic::Threads.Atomic{Int64}, number::Int64) = isless(atomic.value, number)

function divid_into_intervals(input_vector::Vector{<:Any}, intervall::Int)
    rest = length(input_vector) % intervall
    div = (length(input_vector) - rest) / intervall

    intervalls = UnitRange[]
    start = 0
    stop = 0
    for i in 1:div
        start = Int(((i-1) * intervall)) + 1
        stop  = Int(start + intervall) -1
        push!(intervalls, start:stop)
    end
    if rest > 0
        start = stop + 1
        stop = stop + rest
        push!(intervalls, start:stop)
    end

    views = SubArray[]
    for rang in intervalls
        v = view(input_vector, rang)
        push!(views, v)
    end
    return views
end
