local skynet = require "skynet"
require "skynet.manager"
local cluster = require "skynet.cluster"

local skynet_node_name = ...

local CMD = {}

local User_Map = {}
local FD_Map = {}
local subid = 1

---------------------Login Node-------------------------------------------
------------------------Login Node-------------------------------------------
function CMD.access(token)
    --TODO: 超时处理 长时间 登陆验证成功但是不 进入游戏token
    subid = subid + 1
    token.subid = subid
    User_Map[token.uid] = { token = token, tm = os.time(), }
    return subid
end

---------------------Login Node-------------------------------------------
------------------------Login Node-------------------------------------------

------------------------Gate Service-------------------------------------------
------------------------Gate Service-------------------------------------------

function CMD.connect(gate, conn)
    conn.gate = gate
    FD_Map[conn.fd] = conn
end

function CMD.logout(conn)
    INFO("game hubd logout", inspect(conn))
    if conn.uid then
        skynet_send(conn.agent, "logout", conn)
        cluster.send("loginnode", "logind", "logout", {uid = conn.uid,})
        User_Map[conn.uid] = nil
    else
        if conn.fd then
            FD_Map[conn.fd] = nil
        end
    end
end

------------------------Gate Service-------------------------------------------
------------------------Gate Service-------------------------------------------

local tcount = 15 --握手超时
local function handshake_timeout()
    while true do
        local tm = skynet.now()
        local tbl = {}

        do
            for k, v in pairs(User_Map) do
                if v.conn then
                    v.tm = skynet.now()
                else
                    if tm - v.tm >= tcount then
                        table.insert(tbl, k)
                    end
                end
            end
        end

        do
            for m=1, #tbl do
                local uid = tbl[m]
                cluster.send("loginnode", "logind", "logout", {uid = uid,})
                User_Map[uid] = nil
            end
        end

        skynet.sleep(1500)	-- 15 sec
    end
end

------------------------Auth Client Handshake Logic-------------------------------------------
------------------------Auth Client Handshake Logic-------------------------------------------
function CMD.kick(data)
    local user = User_Map[data.uid]
    if user then
        skynet_send(user.conn.gate, "kick", user.conn.fd)
    end
end

function CMD.handshake(fd, args)
    local conn = FD_Map[fd]
    if not conn then
        return 1
    end

    local user = User_Map[args.uid]
    if not user then
        return 2
    end

    local token = user.token
    if token.secret ~= args.secret or tostring(token.subid) ~= args.subid then
        return 3, {res = SYSTEM_ERROR.unauthorized}
    end

    local is_reconnect = false
    if user.conn then
        is_reconnect = true
        skynet_send(user.conn.gate, "kick", user.conn.fd, true)
    else
        --TODO: agent 池
        user.conn = table.clone(conn)
        user.agent = skynet_call(".agent_mgr", "get", user.conn.protocol)
    end

    local sip = string.split(user.conn.ip, ":")
    local role = skynet_call(user.agent, "start", {
        fd = user.conn.fd,
        ip = sip[1],
        port = sip[2],
        protocol = user.conn.protocol,
        openid = args.uid, --以免和agent中的uid 重复
        secret = user.token.secret,
        serverId = user.token.serverId,
        is_reconnect = is_reconnect,
        skynet_node_name = skynet_node_name,
    })

    local res = skynet_call(user.conn.gate, "register", {
        fd = fd,
        uid = user.token.uid,
        agent = user.agent,
    })
    assert(res)
    FD_Map[fd] = nil

    return SYSTEM_ERROR.success, {role = role, }
end

------------------------Auth Client Handshake Logic-------------------------------------------
------------------------Auth Client Handshake Logic-------------------------------------------
local hub_mod = require "hub.index"

skynet.start(function()
    skynet.fork(handshake_timeout)

    hub_mod.init(skynet_node_name)

    skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = assert(CMD[cmd], cmd .. "not found")
        skynet.retpack(f(...))
    end)

    skynet.register('.' .. SERVICE_NAME)
end)