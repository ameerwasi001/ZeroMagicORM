require 'pg'

DBAuth = Struct.new(:host, :port, :db, :user, :pass)

def pg_query(auth, q)
    conn = PG.connect(auth.host, auth.port, "", "", auth.db, auth.user, auth.pass)
    return conn.exec(q)
end