module Platforms
    SQLITE = "SQLITE"
end

def unsupported_platform(platform)
    raise StandardError.new("The " + platform + " platform is not supported, the only supported ones right now are " + [Platforms::SQLITE].join(", "))
end