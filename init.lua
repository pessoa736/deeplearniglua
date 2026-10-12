local matriz = require "matriz"
local plt = require "matplotlib"




---@class network
---@field layers Matriz[]
---@field activactions  table<integer, fun(n: number,i?: integer, j?:integer):number>
---@field weigth Matriz[]
---@field bias Matriz[]
---@field __index network?
local Network = {}
Network.__index = Network



--- @param layers integer[]
--- @param activactions? table<integer, fun(n: number,i?: integer, j?:integer):number>|fun(n: number,i?: integer, j?:integer):number
--- @return network?
--- @return string
function Network.nova(layers, activactions)
    if not layers then return nil, "falta colocar as informações de layer" end
    if type(layers)~="table" then return nil, "layers tem que ser table" end
    if #layers<=1 then return nil, "layers deve conter mais de um elemento" end

    ---@type network
    local net = {
        layers = {},
        activactions = {},
        weigth = {},
        bias = {},
    }

    for i = 1, #layers do
        net.layers[i] = matriz.nova(1, layers[i], 0)

        if  i > 1 then

            net.weigth[i] = matriz.aleatoria(layers[i-1], layers[i], -1000, 1000)/1000
            net.bias[i] = matriz.aleatoria(1, layers[i], -1000, 1000)/1000

            ---@type fun(n: number,i?: integer, j?:integer):number
            local function no_activation_param(n) return n end
            
            local fun
            if type(activactions)=="function" then fun  = activactions end
            if type(activactions)=="table" then fun  = activactions[i-1] end

            net.activactions[i] = fun or no_activation_param
        end
    end

    return setmetatable(net, Network), "matriz criada com sucesso"
end




function Network:forward(entrada)
    if entrada and type(entrada)=="table" then
        self.layers[1] = entrada
    end
    for i=2, #self.layers do
        
        local z = self.layers[i-1] * self.weigth[i] + self.bias[i]

        self.layers[i] = z:map(self.activactions[i])
    end
end



---@param x Matriz
---@param a Matriz
---@param dy Matriz
---@param w Matriz
---@param b Matriz
---@param lr number
---@param f function
function Network.backprop(x, a, dy, w, b, lr, f)
    local df = function (x) return (f(x+0.01) - f(x))/0.01 end

    local dz = dy:copiar():map(function (v, i, j)
        return v * a:map(df)[i][j]
    end)

    local dW = x:transposta() * dz
    local db = dz:soma_linhas()
    local dx = dz * w:transposta()

    return w - dW * lr, b - db * lr, dx
end

local function mean(m)
    local sum, i =0, 0
    if type(m) == "number" then return m end
    m:copiar():map(function (valor, linha, coluna)
        sum = sum + valor
        i = i + 1
        return valor
    end)
    return sum/i
end

---@param expected Matriz
---@param learning_rate number
---@param epoch integer
function Network:trainer(entrada, expected, learning_rate, epoch, batch_size, record)
    batch_size = batch_size or 32

    for i= 1, epoch or 1000 do
        local n = #self.layers

        self:forward(entrada)


        local N = expected.linhas * 2
        local dif = self.layers[n] - expected
        local dy = dif * (2/N)
        local loss = (dif*dif:transposta()):determinante()

        if i%(N) == 0 then
            print(
                ("epoch: %s;\tloss: %s; ")
                :format(
                    i,
                    loss
                )
                    
            )
            if record and type(record) == "table" then
                if not record.loss then record.loss = {} end

                record.loss[i] = loss
            end
        end

        for i = n, 2, -1 do
            self.weigth[i], self.bias[i], dy = self.backprop(
                self.layers[i-1],
                self.layers[i],
                dy,
                self.weigth[i],
                self.bias[i],
                learning_rate or 0.01,
                self.activactions[i]
            )
        end
    end
end



--- test
if select("#", ...) then

    local record = {}
    local batch = 500
    local epoch = 10000
    local learning_rate = 0.01
    
    local _n = 5
    local N = _n * 3

    local pontos, alvo = {}, {}
    for i = 1, N do
        pontos[i] = i/_n          -- 0.1 .. 3.0
        alvo[i]   = math.sin(i/_n)
    end
    local x = matriz.de_tabela({pontos})
    local y = matriz.de_tabela({alvo})


    local n, msg = Network.nova(
        {
            x.colunas,
            8, 8, 8,
            y.colunas
        },
        function (n)
            return 1/(1 + math.exp(-n))
        end
    )

    if not n then
        print(msg)
    end


    n:trainer(
        x,
        y,
        learning_rate,
        epoch,
        batch,
        record
    )

    local fig = plt.figure(640, 480)
    fig:xlabel("epoch")
    fig:ylabel("loss")
    fig:grid(true)

    local ys = record.loss
    local xs = {} do
        for i = 1, N do
            xs[i] = i/N
        end
    end
    fig:plot(xs, y[#y], {color=plt.RED, label="real"})
    fig:plot(xs, n.layers[#n.layers][1], {color=plt.BLUE, label="predict"})
    fig:legend(true)

    print(n.layers[#n.layers])
    fig:save("treinamento.png")
end



