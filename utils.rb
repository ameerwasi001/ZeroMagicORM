def constraint_name(name, k, constraint)
    cons = constraint.split(" ").join("_")
    return "#{name}_#{k}_#{cons}"
end

def indent(str)
    arr = str.split("\n")
    i = 0
    while i < arr.length
        arr[i] = "  " + arr[i]
        i += 1
    end
    return arr.join("\n")
end

class Context
    attr_accessor :starting, :ending

    def initialize(starting, ending)
        @starting = starting
        @ending = ending
    end

    def add_start(s)
        @starting.append(s)
    end

    def add_end(s)
        @ending.append(s)
    end

    def generate(main)
        @starting.map{|x| x + ";\n"}.join("") + "\n\n" + main + "\n\n" + @ending.map{|x| x + ";\n"}.join("") + "\n"
    end
end

def create_seq(ctx, table_name, column, seq_name)
    ctx.add_start("DO\n$$\nBEGIN\n  CREATE SEQUENCE #{seq_name};\nEXCEPTION WHEN duplicate_table THEN\n  -- do nothing, it's already there\nEND\n$$ LANGUAGE plpgsql")
    ctx.add_end("ALTER SEQUENCE #{seq_name} OWNED BY #{table_name}_.#{column.to_s}")
end