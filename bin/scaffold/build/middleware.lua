local sgmatch = string.gmatch
local utils = require 'bin.scaffold.utils'

local gitignore = [[
# lor
client_body_temp
fastcgi_temp
logs
proxy_temp
tmp
uwsgi_temp

# Compiled Lua sources
luac.out

# luarocks build files
*.src.rock
*.zip
*.tar.gz

# Object files
*.o
*.os
*.ko
*.obj
*.elf

# Precompiled Headers
*.gch
*.pch

# Libraries
*.lib
*.a
*.la
*.lo
*.def
*.exp

# Shared objects (inc. Windows DLLs)
*.dll
*.so
*.so.*
*.dylib

# Executables
*.exe
*.out
*.app
*.i*86
*.x86_64
*.hex
]]




local index_view_tpl = [[
<!DOCTYPE html>
<html>
<style>
body {
    font: 400 14px/1.6 "Open Sans",sans-serif;
    color: #555;
}

.lor {
    margin: 100px auto;
    width: 800px;
}

.name {
    display: block;
    font: 100 4.5em "Helvetica Neue","Open Sans",sans-serif;
    margin-bottom: 0.25em;
}

a {
    color: #259DFF;
    text-decoration: none;
}

.description {
  position: relative;
  top: -5px;
  font: 100 3em "Helvetica Neue","Open Sans",sans-serif;
  color: #AEAEAE;
}
</style>
<body>

<div class="lor">
<a href="#" class="name">{{name}}</a>
<span class="description">{{desc}}</span>
</div>
</body>
</html>
]]



local main_tpl = [[
local lor = require("lor.index")
local router = require("app.router")
local app = lor()

-- session和cookie支持，如果不需要可注释以下四行
local middleware_cookie = require("lor.lib.middleware.cookie")
local middleware_session = require("lor.lib.middleware.session")
app:use(middleware_cookie())
app:use(middleware_session())

app:conf("view enable", true)
app:conf("view engine", "tmpl")
app:conf("view ext", "html")
app:conf("views", "./app/views")

app:use(function(req, res, next)
    -- 插件，在处理业务route之前的插件，可作编码解析、过滤等操作
    next()
end)


router(app) -- 业务路由处理


-- 404 error
app:use(function(req, res, next)
    if req:is_found() ~= true then
        res:status(404):send("sorry, not found.")
    end
end)


-- 错误处理插件，可根据需要定义多个
app:erroruse(function(err, req, res, next)
    -- err是错误对象
    res:status(500):send(err)
end)

app:run() -- 启动lor

]]


local router_tpl = [[
-- 业务路由管理
local userRouter = require("app.routes.user")
local testRouter = require("app.routes.test")

return function(app)

    -- group router, 对以`/user`开始的请求做过滤处理
    app:use("/user", userRouter())

    -- group router, 对以`/test`开始的请求做过滤处理
    app:use("/test", testRouter())

    -- 除使用group router外，也可单独进行路由处理，支持get/post/put/delete...

    -- welcome to lor!
    app:get("/", function(req, res, next)
        res:send("hi! welcome to lor framework.")
    end)

    -- hello world!
    app:get("/index", function(req, res, next)
        res:send("hello world!")
    end)

    -- render html, visit "/view" or "/view?name=foo&desc=bar
    app:get("/view", function(req, res, next)
        local data = {
            name =  req.query.name or "lor",
            desc =   req.query.desc or 'a framework of lua based on OpenResty'
        }
        res:render("index", data)
    end)
end

]]


local user_router_tpl = [[
local lor = require("lor.index")
local userRouter = lor:Router() -- 生成一个router对象


-- 按id查找用户
userRouter:get("/query/:id", function(req, res, next)
    local query_id = req.params.id -- 从req.params取参数
    res:json({
        id = query_id,
        desc = "this is from user router"
    })
end)

-- 删除用户
userRouter:post("/delete/:id", function(req, res, next)
    local id = req.params.id
    res:json({
        id = id,
        desc = "delete user " .. id
    })
end)


return userRouter

]]

local test_router_tpl = [[
local lor = require("lor.index")
local testRouter = lor:Router() -- 生成一个router对象


-- 按id查找用户
testRouter:get("/hello", function(req, res, next)
    res:send("hello world!")
end)

return testRouter
]]

local middleware_tpl = [[

### 自定义插件目录(define your own middleware)


You are recommended to define your own middlewares and keep them in one place to manage.

建议用户将自定义插件存放在此目录下统一管理，然后在其他地方引用，插件的格式如下:

```
local middleware =  function(params)
    return function(req, res, next)
        -- do something with req/res
        next()
    end
end

return middleware
```

]]

local static_tpl = [[

### 静态文件目录(static files directory)

nginx对应配置为

```
location /static {
    alias app/static;
}
```

]]

local ngx_conf_directory = [[

### nginx configuration directory

]]


local ngx_config = require 'bin.scaffold.nginx.config'
local ngx_conf_template = require 'bin.scaffold.nginx.conf_template'
local function nginx_conf_content()
    -- read nginx.conf file
    local nginx_conf_template =  ngx_conf_template.get_ngx_conf_template()

    -- append notice
    nginx_conf_template = [[
#generated by `web framework`
    ]] .. nginx_conf_template

    local match = {}
    local tmp = 1
    for v in sgmatch(nginx_conf_template , '{{(.-)}}') do
        match[tmp] = v
        tmp = tmp + 1
    end

    for _, directive in ipairs(match) do
        if ngx_config[directive] ~= nil then
            nginx_conf_template = string.gsub(nginx_conf_template, '{{' .. directive .. '}}', ngx_config[directive])
        else
            nginx_conf_template = string.gsub(nginx_conf_template, '{{' .. directive .. '}}', '#' .. directive)
        end
    end

    return nginx_conf_template
end
local ngx_conf_tpl = nginx_conf_content()


local start_sh = [[
#!/bin/sh

#####################################################################
# usage:
# sh start.sh -- start application @dev
# sh start.sh ${env} -- start application @${env}

# examples:
# sh start.sh prod -- use conf/nginx-prod.conf to start OpenResty
# sh start.sh -- use conf/nginx-dev.conf to start OpenResty
#####################################################################

if [ -n "$1" ];then
    PROFILE="$1"
else
    PROFILE=dev
fi

mkdir -p logs & mkdir -p tmp
echo "Use profile: "${PROFILE}
nginx -p `pwd`/ -c conf/nginx-${PROFILE}.conf
]]


local stop_sh = [[
#!/bin/sh

#####################################################################
# usage:
# sh stop.sh -- stop application @dev
# sh stop.sh ${env} -- stop application @${env}

# examples:
# sh stop.sh prod -- use conf/nginx-prod.conf to stop OpenResty
# sh stop.sh -- use conf/nginx-dev.conf to stop OpenResty
#####################################################################

if [ -n "$1" ];then
    PROFILE="$1"
else
    PROFILE=dev
fi

mkdir -p logs & mkdir -p tmp
echo "Use profile: "${PROFILE}
nginx -s stop -p `pwd`/ -c conf/nginx-${PROFILE}.conf
]]

local reload_sh = [[
#!/bin/sh

#####################################################################
# usage:
# sh reload.sh -- reload application @dev
# sh reload.sh ${env} -- reload application @${env}

# examples:
# sh reload.sh prod -- use conf/nginx-prod.conf to reload OpenResty
# sh reload.sh -- use conf/nginx-dev.conf to reload OpenResty
#####################################################################

if [ -n "$1" ];then
    PROFILE="$1"
else
    PROFILE=dev
fi

mkdir -p logs & mkdir -p tmp
echo "Use profile: "${PROFILE}
nginx -s reload -p `pwd`/ -c conf/nginx-${PROFILE}.conf
]]

local new_middleware_tpl = [[
return function(text)
        return function(req, res, next)
            res:set_header('X-Powered-By', text)
            next()
        end
end
]]

local Generator = {}

Generator.files = {
}


function Generator.new(project_name, middleware_name)
    print('Creating middleware: ' .. middleware_name .. '...')
    local middleware_path_file_name = "app/middleware/"..middleware_name..".lua"
    table.insert(Generator.files,  {[middleware_path_file_name] = new_middleware_tpl})
    Generator.create_files(project_name)
end

function Generator.create_files(parent)
    for k, v in pairs(Generator.files) do
        for file_path, file_content in pairs(v) do
	    local full_file_path = parent .. '/' .. file_path
            local full_file_dirname = utils.dirname(full_file_path)
            os.execute('mkdir -p ' .. full_file_dirname .. ' > /dev/null')

	    local fw = io.open(full_file_path, 'w')
            fw:write(file_content)
            fw:close()
            print('  created file ' .. full_file_path)
        end
    end
end

return Generator




