using TypeDBClient: dbconnect, insert, commit, transaction, Proto
using DataFrames: DataFrame, eachrow
using CSV: CSV
using Base.Threads
using Distributed

function load_data()
    return DataFrame(CSV.File("dataset/uniprot/uniprot.csv"))
end

function make_queries(df::DataFrame)
    queries = String[]
    for row in eachrow(df)
        str = "insert \$a isa protein, has uniprot-id \"$(row[1])\", has uniprot-name \"$(row[4])\";"
        push!(queries, str)
    end
    return queries
end

function single_insert_records(queries::Vector{String}, batch_size = 500)
    dbconnect("127.0.0.1") do client
        open(client, "biograkn") do session
            for batched_queries in Iterators.partition(queries, batch_size)
                write(session) do trans
                    for query in batched_queries
                        insert(trans, query)
                    end
                    commit(trans)
                end
            end
        end
    end
end

# This function runs on a single thread.
# Pass `num` as a number to load only a partial array.
function single_run(; num = :all, batch_size = 500)
    df = load_data()
    queries = make_queries(df)
    N = num == :all ? length(queries) : num
    insert_records(queries[1:N], batch_size)
    return nothing
end

#=
How to run:
1. Start julia with multiple workers
2. Activate project, include this file, and prepare queries everywhere
3. Invoke the `parallel_run` function

$ julia --project=. -p 16
@everywhere import Pkg
@everywhere Pkg.activate(".")
@everywhere include("src/load_dataset.jl")
@everywhere queries = make_queries(load_data())
@everywhere batch_size = 500
@time parallel_run()

The first time takes longer as usual and gives error (should investigate later).
Run the function again to get warmed-up timings.
=#
function parallel_run()
    @everywhere batches = collect(Iterators.partition(queries, batch_size))
    @info "Distributing work over " * string(length(batches)) * " batches"
    @sync @distributed for i in 1:length(batches)
        batched_queries = batches[i]
        dbconnect("127.0.0.1") do client
            open(client, "biograkn") do session
                write(session) do trans
                    for query in batched_queries
                        insert(trans, query)
                    end
                    commit(trans)
                end
            end
        end
    end
end

function get_env_batch_size()
    default_batch_size = 500
    try
        return parse(Int, get(ENV, "BATCH_SIZE", "$default_batch_size"))
    catch ex
        @warn "Unable to parse BATCH_SIZE, defaulting to $default_batch_size"
        return default_batch_size
    end
end