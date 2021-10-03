import Base: isless

isless(atomic::Threads.Atomic{Int64}, number::Int64) = isless(atomic.value, number)
