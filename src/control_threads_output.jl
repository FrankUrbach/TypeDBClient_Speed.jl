# should be your environment and have for nothing to do whith the speed_test
cd("/Users/frank/.julia/dev/TypeDBClient_Speed")
using Pkg
Pkg.activate(".")

using TypeDBClient
using TypeDBClient: CoreSession, CoreClient

using UUIDs
g = TypeDBClient
client = g.CoreClient("127.0.0.1",1729)
Optional{T} = Union{Nothing,T}

# @info "deleting all databases"
# dbs = g.get_all_databases(client)
# for item in dbs
#     g.delete_database(client, item.name)
# end

@info "create database typedb"

if !g.contains_database(client, "typedb")
    g.create_database(client, "typedb")
end
sess = CoreSession(client, "typedb" , g.Proto.Session_Type.DATA, request_timout=Inf)

function trans_func(task)
    return task
end

function coreTransaction(session::g.CoreSession,
    sessionId::g.Bytes,
    type::g.EnumType,
    options::g.TypeDBOptions,
    grpc_controller;
    request_timout::Real=session.request_timeout)

    type = type
    options = options
    input_channel = Channel{g.Proto.Transaction_Client}(10)
    proto_options = g.copy_to_proto(options, g.Proto.Options)

    res_imm = g.Proto.transaction(session.client.core_stub.asyncStub , grpc_controller, input_channel, trans_func)
    req_result, status = fetch(res_imm)

    output_channel = g.grpc_result_or_error(req_result, status, result->result)
    println(status)

    # open_req = g.TransactionRequestBuilder.open_req(session.sessionID, type, proto_options,session.networkLatencyMillis)

    # bidirectionalStream = g.BidirectionalStream(input_channel, output_channel, status)
    # trans_id = uuid4()
    # result = g.CoreTransaction(type, options, bidirectionalStream, trans_id, sessionId, request_timout, session)

    # # The following is only for warming up Transaction. If we didn't do this
    # # it could happen that a transaction reach a timeout.

    # req_result = g.execute(result, open_req, false)
    # kind_of_result = g.Proto.which_oneof(req_result, :res)
    # getproperty(req_result, kind_of_result)

    return input_channel
end

@info "beginning Threads"
client_in = CoreClient("127.0.0.1", 1729)
sess_in = CoreSession(client_in, "typedb", g.Proto.Session_Type.DATA, request_timout=Inf)
grpc_controller = g.gRPCController(request_timeout=sess_in.request_timeout)
Threads.@threads for i in 1:2
    @info "here I am"
    res = coreTransaction(sess_in,
    sess_in.sessionID,
    g.Proto.Transaction_Type.WRITE,
    g.TypeDBOptions(),
    grpc_controller,
    request_timout = sess_in.request_timeout)
    @info "I'm close to end"
end

# close(sess)
