using TypeDBClient
using DataFrames
using CSV
using BenchmarkTools
using Profile
using ProfileSVG
using ProfileView
using Dates


g = TypeDBClient

include("define_schema.jl")
include("utils.jl")

database_name = "biograkn"

client = g.CoreClient("127.0.0.1",1729)

delete_all_dbs_create_db(client, database_name)
@info "Deleted all databases, create database $database_name and the schema"

function uniprot(client::TypeDBClient.AbstractCoreClient, database_name::String, make_inserts::Bool=true)
    # Uniprot
        @info "1. Uniprot"
        df = CSV.File(joinpath(@__DIR__, "../dataset/uniprot/uniprot.csv"), delim="\t") |> DataFrame

        query_strings = String[]

        start_preparing = time()
        data_pair = Pair[]
        for row in eachrow(df)
            tmp_string = "insert \$a isa protein, has uniprot-id \"$(row[1])\", has uniprot-name \"$(row[4])\";"
            push!(query_strings, tmp_string)
            push!(data_pair, (row[1]=>row[4]))
        end
        end_preparing = time()

        # @info "Time for preparing: $(end_preparing - start_preparing)"

        sess = g.CoreSession(client, database_name , g.Proto.Session_Type.DATA, request_timout=Inf)

        if make_inserts
            start_insert = time()
               res_insert = insert_data(sess, query_strings, 1000)
            end_insert = time()
            @info "Uniprot in $(end_insert - start_insert) s"
        end
        return res_insert
end

function transaction_insert(trans::g.AbstractCoreTransaction, data, counter)
    time1 = time()
    @sync @async for row in data
        g.insert(trans, row)
    end
    time2 = time()
    @info "Einer fertig time: $(round(time2 - time1, digits=2)) s : counter: $counter"
end

function insert_data(session::g.AbstractCoreSession, data::Vector{String}, intervall::Int64 = 100)
    ranges = divid_into_intervals(data, intervall)
    @info "Slice to insert: $(length(ranges))"
    ins_number = Threads.Atomic{Int64}(0)
    times = Float64[]
    @sync for rang in ranges
        Threads.atomic_add!(ins_number, 1)
        Threads.@spawn begin
            trans = g.transaction(session, g.Proto.Transaction_Type.WRITE)
            transaction_insert(trans, rang, ins_number)
            g.commit(trans)
        end
        push!(times, time())
        @info "Process $(ins_number.value) started at: $(now())"
    end
    return times
end

times = uniprot(client, database_name, true)

for i in 2:length(times)
    @info round(times[i] - times[i-1], digits=2)
end
