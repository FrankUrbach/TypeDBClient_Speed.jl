function delete_all_dbs_create_db(client::TypeDBClient.AbstractCoreClient, database_name::String)
    dbs = g.get_all_databases(client)
    for item in dbs
        g.delete_database(client, item.name)
    end

    g.create_database(client, database_name)

    sess = g.CoreSession(client, database_name , g.Proto.Session_Type.SCHEMA, request_timout=Inf)
    trans = g.transaction(sess, g.Proto.Transaction_Type.WRITE)

    define_string = read(open("typedb_defines/disease-netowrk-schema.gql"), String)

    g.define(trans, define_string)

    g.commit(trans)
    g.close(sess)
end
