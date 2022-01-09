require 'sqlite3'

def sqlite_query(file, q)
    client = SQLite3::Database.new 'file.db'
    return client.execute(q)
end