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

            net.weigth[i] = matriz.aleatoria(layers[i-1], layers[i], 1000, 1000)/1000
            net.bias[i] = matriz.aleatoria(1, layers[i], 1000, 1000)/1000

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




function Network:forward()
    for i=2, #self.layers do
        
        local z = self.layers[i-1] * self.weigth[i] + self.bias[i]

        self.layers[i] = z:map(self.activactions[i])
    end
end

---@type fun(m:Matriz|number):number
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

---@param x Matriz
---@param dy Matriz
---@param w Matriz
---@param b Matriz
---@param lr number
function Network.backprop(x, dy, w, b, lr)
    local dW = x:transposta() * dy
    local db = x:soma_linhas()
    local dx = dy * w:transposta()

    return w - dW * lr, b + db * lr, dx
end



---@param expected Matriz
---@param learning_rate number
---@param epoch integer
function Network:trainer(expected, learning_rate, epoch)

    for i= 1, epoch or 1000 do
        self:forward()

        local n = #self.layers
        local N = expected.linhas

        local dy = (self.layers[n] - expected) * (2/N)

        for i = n, 2, -1 do
            local erro
            self.weigth[i], self.bias[i], dy = self.backprop(
                self.layers[i-1],
                dy,
                self.weigth[i],
                self.bias[i],
                learning_rate or 0.01
            ) 
        end
    end
end



--- test


local n, msg = Network.nova(
    {2, 3, 2},
    function (n)
        return math.max(0, n)
    end
)

if not n then
    print(msg)
end


n:trainer(
    matriz.de_tabela({{1, 0.1}}),
    0.001,
    10000
)

print(n.layers[#n.layers])




