class Schema
    attr_accessor :internal_dict

    def initialize(schema)
        @internal_dict = {}
        for table in schema
            @internal_dict[table.name] = table
        end
    end

    def register(table)
        @internal_dict[table.name] = table
    end

    def to_dict
        return @internal_dict.clone
    end

    def to_s
        return @internal_dict.to_s
    end

    def initialize_model
        for _, table in @internal_dict
            table.initialize_model(self)
        end
    end
end