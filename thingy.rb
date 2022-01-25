require 'set'
require 'json'

require_relative 'fields.rb'
include Fields
require_relative 'table.rb'
include TableDefintion
require_relative 'tableDiff.rb'
require_relative 'migration.rb'
require_relative 'platforms.rb'
require_relative 'schema.rb'
require_relative 'query.rb'

class User < Table
    attr_accessor :table

    def create
        self.name = "User"
        @table[:profile] = ForeignKeyField.new(reference: "Profile")
        @table[:username] = CharField.new(max_length: 128, constraints: [Unique.new])
        @table[:password] = CharField.new(max_length: 255)
        @table[:bio] = TextField.new(constraints: [Nullable.new])
    end
end

class User2 < Table
    attr_accessor :table

    def create
        self.name = "User"
        @table[:profile] = ForeignKeyField.new(reference: "Profile")
        @table[:username] = CharField.new(max_length: 255)
        @table[:password] = CharField.new(max_length: 255, constraints: [Nullable.new])
        @table[:phone_number] = IntField.new(field_type: IntTypes::Big, constraints: [Unique.new])
    end
end

class Post < Table
    attr_accessor :table

    def create
        self.name = "Post"
        @table[:user] = ForeignKeyField.new(reference: "User")
        @table[:title] = CharField.new(max_length: 500)
        @table[:text] = TextField.new(constraints: [Nullable.new])
    end
end

class Profile < Table
    attr_accessor :table

    def create
        self.name = "Profile"
        @table[:user] = ForeignKeyField.new(reference: "User")
        @table[:title] = CharField.new(max_length: 500)
        @table[:text] = TextField.new(constraints: [Nullable.new])
    end
end

dbAuth = DBAuth.new("localhost", 5432, "orm_test", "postgres", "root")
DBConn.create(dbAuth)

Users = User2.new
Profiles = Profile.new
Posts = Post.new

schema = Schema.new([])
schema.register(Users)
schema.register(Profiles)
schema.register(Posts)

schema.initialize_model

usr_migrations = Migrations.new("usr")
usr_migrations.migrate(dbAuth, schema, Platforms::POSTGRES)

# phone_nums = [93777809, 93971805, 95277105]
# usernames = ["ameershah", "ameerwasi", "ameerwasi001"]
# passwords = ["mx12345678", "mio90xa11", "wasiameer"]

# i = 0
# while i < 3
#     user = Users.init
#     profile = Profiles.init

#     profile[:user] = user
#     profile[:title] = "My Title #{i+1}"
#     profile[:text] = "A description #{i+1}"

#     user[:profile] = profile
#     user[:username] = usernames[i]
#     user[:password] = passwords[i]
#     user[:phone_number] = phone_nums[i]
#     user.save
#     i+=1
# end

# user = Users.where({id: 2}).first
# post = Posts.init
# post[:user] = user
# post[:title] = "Second user, first post"
# post[:text] = "Text about this post from 2nd user"
# post.save

print Users.get({id: 2})[:posts].first[:user][:profile], "\n"