local msg = require 'mp.msg'

mp.add_hook('on_load', 50, function ()
    local realurl = mp.get_opt("real-stream-url")
    if realurl then
        mp.set_property("stream-open-filename", realurl)
    else
        msg.error("No real-stream-url option was provided")
    end
end)
