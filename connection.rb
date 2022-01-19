require 'pg'

DBAuth = Struct.new(:host, :port, :db, :user, :pass)

def pg_query(auth, q)
    conn = PG.connect(auth.host, auth.port, "", "", auth.db, auth.user, auth.pass)
    return conn.exec(q)
end

class DBConn
    @@dbAuth = nil
    @@connection = nil

    def self.create(auth)
        @@dbAuth = auth
    end

    def self.getConnection
        if @@connection == nil
            @@connection = PG.connect(@@dbAuth.host, @@dbAuth.port, "", "", @@dbAuth.db, @@dbAuth.user, @@dbAuth.pass)
            @@connection.type_map_for_results = PG::BasicTypeMapForResults.new @@connection
        end
        return @@connection
    end
end