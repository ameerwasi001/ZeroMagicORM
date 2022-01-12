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