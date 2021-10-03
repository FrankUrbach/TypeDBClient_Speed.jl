# How to run:
#    julia --project=. scripts/parallel.jl
#
# To use a different batch size, set environment variable:
#    export BATCH_SIZE=1000
#    julia --project=. scripts/parallel.jl

using Distributed
using TypeDBClient


@info "Delete database biograkn, create it again and define the schema"
rootdir = joinpath(@__DIR__, "..")
include("$rootdir/src/define_schema.jl")

TypeDBClient.dbconnect("127.0.0.1") do client
    delete_db_create_db(client, "biograkn")
end

@everywhere ENV["BATCH_SIZE"] = 1000

@info "Preparing worker processes"
procs = addprocs(21)
@everywhere rootdir = joinpath(@__DIR__, "..")
@everywhere import Pkg
@everywhere Pkg.activate(rootdir)
@everywhere include("$rootdir/src/load_dataset.jl")

@info "Loading function in master process"
include("$rootdir/src/load_dataset.jl")

@info "Loading data to master process"
queries = make_queries(load_data())

batches = collect(Iterators.partition(queries, 1000))
@info "Data is divided into: $(length(batches))"

failure_arr = String[]

const remote_channel = RemoteChannel(()->Channel{Tuple}(10))
const failure_channel = RemoteChannel(()->Channel(10))
const result_channel = RemoteChannel(()->Channel(10))

@info "Start failure collecting"
@async begin
    while isopen(failure_channel)
        yield()
        if isready(failure_channel)
            push!(failure_arr, take!(failure_channel))
        end
    end
end

@info "Warming up"
@sync for n in procs
    @info "Warming up worker $n"
    @async remotecall_wait(warmup, n)
end

@info "Start worker processes"
for n in procs
    @spawnat n parallel_channel(remote_channel, failure_channel, result_channel)
end

@info "Put work on the workers"
for i in 1:length(batches)
    @async put!(remote_channel, (i,batches[i]))
end


for _ in 1:length(batches)
    take!(result_channel)
end

length(failure_arr)
# put!(failure_channel, "hier")

# filter!(x->x != "hier", failure_arr)

# client = CoreClient("127.0.0.1", 1729)
# sess = CoreSession(client, "biograkn", Proto.Session_Type.DATA, request_timout = Inf, error_time = 20)
# trans = transaction(sess, Proto.Transaction_Type.WRITE)

# for query in failure_arr
#    @info insert(trans, query)
# end

# commit(trans)
# @everywhere batch_size = get_env_batch_size()
# @info "Batch size = $(get_env_batch_size())"


# @info "Warming up"
# @time try
#     parallel_run()
# catch ex
#     @info "Got exception... be brave, just continue!"
# end

# @info "Test runs"
# run_results = parallel_run()
# run_reuslts = parallel_run()


# # @time parallel_run()

# rmprocs(procs)
# length(filter(x->isempty(x),run_results))
