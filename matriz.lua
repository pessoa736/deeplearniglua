-- matriz.lua — matrizes em Lua usando metatabelas

--

-- Como usar

--   lua matriz.lua                    roda os exemplos que ficam no fim do arquivo

--   local Matriz = require("matriz")  usa como biblioteca em outro arquivo

--

-- Metamétodos usados

--   __index      os métodos (A:transposta(), ...) são encontrados na "classe" Matriz

--   __newindex   protege o formato: A[1][9] = 0 dá erro em vez de aumentar a linha

--   __add __sub __mul __div __pow __unm   operadores  +  -  *  /  ^  e o menos unário

--   __eq         A == B  (compara tamanho e elementos)

--   __tostring   print(A)

--   __concat     "texto" .. A

--   __len        #A  (número de linhas)

--   __call       A(i, j) lê um elemento conferindo os limites;

--                Matriz{{1, 2}, {3, 4}} cria uma matriz (a metatabela da própria classe)

--   __name       nome do tipo nas mensagens de erro do Lua

--

-- Feito para Lua 5.3/5.4, usando só a biblioteca padrão.



---@alias MatrizPreenchimento number | fun(linha: integer, coluna: integer): number

---Matriz numérica com operações algébricas e acesso protegido aos índices.
---@class Matriz
---@field [integer] number[] Linhas da matriz; cada linha contém os elementos numéricos.
---@field linhas integer Quantidade de linhas.
---@field colunas integer Quantidade de colunas.
---@field precisao integer Algarismos significativos usados na impressão.
---@field tolerancia number Tolerância relativa usada nos algoritmos numéricos.
---@operator add(Matriz): Matriz
---@operator sub(Matriz): Matriz
---@operator mul(Matriz|number): Matriz
---@operator div(number): Matriz
---@operator pow(integer): Matriz
---@operator unm: Matriz
---@operator eq(Matriz): boolean
---@operator len: integer
---@operator concat(any): string
local Matriz = {}

Matriz.__index = Matriz

Matriz.__name = "Matriz"



-- Configurações (quem usa a biblioteca pode mudar)

Matriz.precisao = 6        -- algarismos significativos ao imprimir

Matriz.tolerancia = 1e-12  -- pivô abaixo disso (relativo ao maior elemento) conta como zero



-- ---------------------------------------------------------------------------

-- Funções auxiliares (locais: não fazem parte da API)

-- ---------------------------------------------------------------------------



---@param x any
---@return boolean
local function eh_matriz(x)

  return getmetatable(x) == Matriz

end



---@param n any
---@return boolean
local function inteiro_positivo(n)

  return type(n) == "number" and n >= 1 and n == math.floor(n)

end



-- Número -> texto. Com %g, 2.0 vira "2" e 0.30000000000000004 vira "0.3".

---@param x number
---@return string
local function formatar(x)

  if x == 0 then x = 0 end  -- troca -0.0 por 0 (para não imprimir "-0")

  return string.format("%." .. math.floor(Matriz.precisao) .. "g", x)

end



-- Os "validar/exigir" lançam o erro no nível 3: a linha apontada na mensagem é a

-- de quem chamou o método/operador, e não uma linha de dentro da biblioteca.

---@param linhas number
---@param colunas number
---@return nil
local function validar_dimensoes(linhas, colunas)

  if not (inteiro_positivo(linhas) and inteiro_positivo(colunas)) then

    error("linhas e colunas devem ser inteiros maiores ou iguais a 1", 3)

  end

end



---@param x any
---@param onde string
---@return nil
local function exigir_matriz(x, onde)

  if not eh_matriz(x) then

    error(string.format("%s espera uma matriz (veio %s)", onde, type(x)), 3)

  end

end



---@param a any
---@param b any
---@param operacao string
---@return nil
local function exigir_duas_matrizes(a, b, operacao)

  if not (eh_matriz(a) and eh_matriz(b)) then

    error(operacao .. " só é definida entre duas matrizes", 3)

  end

end



---@param a Matriz
---@param b Matriz
---@param operacao string
---@return nil
local function exigir_mesmo_tamanho(a, b, operacao)

  if a.linhas ~= b.linhas or a.colunas ~= b.colunas then

    error(string.format("%s exige matrizes do mesmo tamanho (recebi %dx%d e %dx%d)",

      operacao, a.linhas, a.colunas, b.linhas, b.colunas), 3)

  end

end



---@param m Matriz
---@param operacao string
---@return nil
local function exigir_quadrada(m, operacao)

  if m.linhas ~= m.colunas then

    error(string.format("%s exige matriz quadrada (esta é %dx%d)",

      operacao, m.linhas, m.colunas), 3)

  end

end



-- ---------------------------------------------------------------------------

-- Metatabela das linhas

-- ---------------------------------------------------------------------------



-- Cada linha da matriz é uma tabela comum, mas com este __newindex ela não deixa

-- criar colunas novas sem querer (A[1][9] = 0): só existem as colunas 1..colunas.

-- (__newindex só é chamado quando a chave ainda NÃO existe; trocar o valor de uma

-- posição que já existe continua sendo uma atribuição normal e rápida.)

local LinhaMT = {}



function LinhaMT.__newindex(linha, j)

  error(string.format("coluna %s fora do intervalo [1, %d]", tostring(j), #linha), 2)

end



function LinhaMT.__tostring(linha)

  local partes = {}

  for k = 1, #linha do partes[k] = formatar(linha[k]) end

  return "[ " .. table.concat(partes, "  ") .. " ]"

end



-- Monta a matriz a partir de uma tabela de linhas já preenchida.

---@param linhas integer
---@param colunas integer
---@param dados number[][]
---@return Matriz
local function montar(linhas, colunas, dados)

  for i = 1, linhas do setmetatable(dados[i], LinhaMT) end

  dados.linhas, dados.colunas = linhas, colunas

  return setmetatable(dados, Matriz)

end



-- ---------------------------------------------------------------------------

-- Construtores

-- ---------------------------------------------------------------------------



-- Matriz.nova(linhas, colunas [, preenchimento])

-- O preenchimento é um número (padrão 0) ou uma função f(i, j) que devolve o valor.

---Cria uma matriz preenchida com um valor constante ou com uma função por elemento.
---@param linhas integer Quantidade de linhas (>= 1).
---@param colunas integer Quantidade de colunas (>= 1).
---@param preenchimento? MatrizPreenchimento Número constante ou função (linha, coluna).
---@return Matriz matriz
function Matriz.nova(linhas, colunas, preenchimento)

  validar_dimensoes(linhas, colunas)

  linhas, colunas = math.floor(linhas), math.floor(colunas)



  local f = preenchimento

  if type(f) ~= "function" then

    local valor = f or 0

    f = function() return valor end

  end



  local dados = {}

  for i = 1, linhas do

    local linha = {}

    for j = 1, colunas do

      local v = f(i, j)

      if type(v) ~= "number" then

        error(string.format("o valor da posição (%d, %d) não é número (veio %s)", i, j, type(v)), 2)

      end

      linha[j] = v

    end

    dados[i] = linha

  end

  return montar(linhas, colunas, dados)

end



-- Matriz.de_tabela({{1, 2}, {3, 4}})  (copia os dados e confere o formato)

---Cria uma matriz copiando uma tabela de linhas retangulares.
---@param t number[][] Dados organizados por linha; todas as linhas devem ter o mesmo tamanho.
---@return Matriz matriz
function Matriz.de_tabela(t)

  if type(t) ~= "table" or type(t[1]) ~= "table" then

    error("de_tabela espera uma tabela de linhas, por exemplo {{1, 2}, {3, 4}}", 2)

  end

  local linhas, colunas = #t, #t[1]

  for i = 1, linhas do

    if type(t[i]) ~= "table" or #t[i] ~= colunas then

      error(string.format("a linha %d não tem %d elementos, como a primeira linha", i, colunas), 2)

    end

  end

  return Matriz.nova(linhas, colunas, function(i, j) return t[i][j] end)

end



---Cria uma matriz preenchida com zeros.
---@param linhas integer Quantidade de linhas.
---@param colunas? integer Quantidade de colunas; por padrão, igual a linhas.
---@return Matriz matriz
function Matriz.zeros(linhas, colunas)

  return Matriz.nova(linhas, colunas or linhas, 0)

end



---Cria uma matriz preenchida com uns.
---@param linhas integer Quantidade de linhas.
---@param colunas? integer Quantidade de colunas; por padrão, igual a linhas.
---@return Matriz matriz
function Matriz.uns(linhas, colunas)

  return Matriz.nova(linhas, colunas or linhas, 1)

end



---Cria uma matriz identidade quadrada de ordem n.
---@param n integer Ordem da matriz.
---@return Matriz matriz
function Matriz.identidade(n)

  return Matriz.nova(n, n, function(i, j) return i == j and 1 or 0 end)

end



-- Matriz.diagonal({2, 5, 7}) -> matriz 3x3 com 2, 5, 7 na diagonal

---Cria uma matriz diagonal a partir dos valores fornecidos.
---@param lista number[] Valores posicionados na diagonal principal.
---@return Matriz matriz
function Matriz.diagonal(lista)

  local n = #lista

  return Matriz.nova(n, n, function(i, j) return i == j and lista[i] or 0 end)

end



-- Inteiros aleatórios entre minimo e maximo (padrão 0 a 9).

-- Chame math.randomseed(os.time()) antes se quiser valores diferentes a cada execução.

---Cria uma matriz com inteiros aleatórios dentro do intervalo informado.
---@param linhas integer Quantidade de linhas.
---@param colunas? integer Quantidade de colunas; por padrão, igual a linhas.
---@param minimo? integer Menor valor possível (padrão 0).
---@param maximo? integer Maior valor possível (padrão 9).
---@return Matriz matriz
function Matriz.aleatoria(linhas, colunas, minimo, maximo)

  minimo, maximo = minimo or 0, maximo or 9

  return Matriz.nova(linhas, colunas or linhas, function() return math.random(minimo, maximo) end)

end



---Converte uma lista em um vetor-coluna.
---@param lista number[] Valores do vetor.
---@return Matriz matriz
function Matriz.vetor_coluna(lista)

  return Matriz.nova(#lista, 1, function(i) return lista[i] end)

end



---Converte uma lista em um vetor-linha.
---@param lista number[] Valores do vetor.
---@return Matriz matriz
function Matriz.vetor_linha(lista)

  return Matriz.nova(1, #lista, function(_, j) return lista[j] end)

end



-- A própria classe também tem metatabela: com __call dá para escrever

--   Matriz{{1, 2}, {3, 4}}     Matriz(2, 3)     Matriz(A)  (cópia)

setmetatable(Matriz, {

  __call = function(_, a, b, c)

    if type(a) == "table" then

      if eh_matriz(a) then return a:copiar() end

      return Matriz.de_tabela(a)

    end

    return Matriz.nova(a, b, c)

  end,

})



-- ---------------------------------------------------------------------------

-- Algoritmos internos (eliminação de Gauss)

-- ---------------------------------------------------------------------------



---@param m Matriz
---@return number
local function maior_modulo(m)

  local maior = 0

  for _, _, v in m:elementos() do

    if math.abs(v) > maior then maior = math.abs(v) end

  end

  return maior

end



-- Resolve A·X = B por Gauss-Jordan com pivotamento parcial.

-- Com B = identidade, X é a inversa de A.

-- Devolve X, ou nil + mensagem se A for singular.

---@param A Matriz
---@param B Matriz
---@return Matriz? solucao
---@return string? motivo
local function resolver_sistema(A, B)

  local n, k = A.linhas, B.colunas

  local a, x = A:copiar(), B:copiar()

  local tol = Matriz.tolerancia * maior_modulo(A)



  for c = 1, n do

-- pivotamento parcial: acha a linha com maior |valor| na coluna c

    local p, maior = c, math.abs(a[c][c])

    for i = c + 1, n do

      local v = math.abs(a[i][c])

      if v > maior then p, maior = i, v end

    end

    if maior <= tol then

      return nil, "a matriz é singular (determinante zero): não tem inversa nem solução única"

    end

    a[p], a[c] = a[c], a[p]

    x[p], x[c] = x[c], x[p]



-- divide a linha do pivô para o pivô virar 1

    local pivo = a[c][c]

    for j = 1, n do a[c][j] = a[c][j] / pivo end

    for j = 1, k do x[c][j] = x[c][j] / pivo end



-- zera a coluna c em todas as outras linhas

    for i = 1, n do

      if i ~= c then

        local f = a[i][c]

        if f ~= 0 then

          for j = 1, n do a[i][j] = a[i][j] - f * a[c][j] end

          for j = 1, k do x[i][j] = x[i][j] - f * x[c][j] end

        end

      end

    end

  end

  return x

end



---@param m Matriz
---@return Matriz? inversa
---@return string? motivo
local function inverter(m)

  return resolver_sistema(m, Matriz.identidade(m.linhas))

end



-- ---------------------------------------------------------------------------

-- Metamétodos

-- ---------------------------------------------------------------------------



-- A[i] = ... só vale para linhas que já existem; criar linha nova é erro.

---@param m Matriz
---@param chave any
---@param valor any
---@return nil
function Matriz.__newindex(m, chave, valor)

  if type(chave) == "number" then

    error(string.format("linha %s fora do intervalo [1, %d]", tostring(chave), m.linhas), 2)

  end

  rawset(m, chave, valor)  -- campos com nome (texto) continuam livres

end



-- print(A)  -> colunas alinhadas, assim:

--   [ 1  2 ]

--   [ 3  4 ]

---@param m Matriz
---@return string texto
function Matriz.__tostring(m)

  local textos, largura = {}, 0

  for i = 1, m.linhas do

    textos[i] = {}

    for j = 1, m.colunas do

      local s = formatar(m[i][j])

      textos[i][j] = s

      if #s > largura then largura = #s end

    end

  end

  local saida = {}

  for i = 1, m.linhas do

    local celulas = {}

    for j = 1, m.colunas do

      celulas[j] = string.format("%" .. largura .. "s", textos[i][j])

    end

    saida[i] = "[ " .. table.concat(celulas, "  ") .. " ]"

  end

  return table.concat(saida, "\n")

end



-- "texto" .. A  e  A .. "texto"  (concatenar sempre vira texto)

---@param a any Valor à esquerda da concatenação.
---@param b any Valor à direita da concatenação.
---@return string texto
function Matriz.__concat(a, b)

  return tostring(a) .. tostring(b)

end



-- #A = número de linhas

---@param m Matriz
---@return integer quantidade_de_linhas
function Matriz.__len(m)

  return m.linhas

end



-- A(i, j) = elemento da linha i, coluna j, com checagem de limites

---Lê um elemento usando a forma A(linha, coluna), verificando os limites.
---@param m Matriz
---@param i integer Índice da linha.
---@param j integer Índice da coluna.
---@return number valor
function Matriz.__call(m, i, j)

  if not (inteiro_positivo(i) and inteiro_positivo(j) and i <= m.linhas and j <= m.colunas) then

    error(string.format("posição (%s, %s) fora da matriz %dx%d", tostring(i), tostring(j), m.linhas, m.colunas), 2)

  end

  return m[i][j]

end



-- A == B  (mesmo tamanho e todos os elementos iguais)

---@param a any
---@param b any
---@return boolean iguais
function Matriz.__eq(a, b)

  if not (eh_matriz(a) and eh_matriz(b)) then return false end

  if a.linhas ~= b.linhas or a.colunas ~= b.colunas then return false end

  for i = 1, a.linhas do

    local la, lb = a[i], b[i]

    for j = 1, a.colunas do

      if la[j] ~= lb[j] then return false end

    end

  end

  return true

end



---@param a Matriz
---@return Matriz resultado
function Matriz.__unm(a)

  return a:map(function(v) return -v end)

end



---@param a Matriz
---@param b Matriz
---@return Matriz resultado
function Matriz.__add(a, b)

  exigir_duas_matrizes(a, b, "a soma")

  exigir_mesmo_tamanho(a, b, "a soma")

  return Matriz.nova(a.linhas, a.colunas, function(i, j) return a[i][j] + b[i][j] end)

end



---@param a Matriz
---@param b Matriz
---@return Matriz resultado
function Matriz.__sub(a, b)

  exigir_duas_matrizes(a, b, "a subtração")

  exigir_mesmo_tamanho(a, b, "a subtração")

  return Matriz.nova(a.linhas, a.colunas, function(i, j) return a[i][j] - b[i][j] end)

end



-- matriz * matriz (produto matricial), matriz * número e número * matriz

---Suporta produto matricial e multiplicação por escalar.
---@param a Matriz|number
---@param b Matriz|number
---@return Matriz resultado
function Matriz.__mul(a, b)

  if type(a) == "number" and eh_matriz(b) then

    ---@cast b Matriz
    return b:map(function(v) return a * v end)

  end

  if eh_matriz(a) and type(b) == "number" then

    ---@cast a Matriz
    return a:map(function(v) return v * b end)

  end

  if eh_matriz(a) and eh_matriz(b) then

    ---@cast a Matriz
    ---@cast b Matriz
    if a.colunas ~= b.linhas then

      error(string.format(

        "não dá para multiplicar %dx%d por %dx%d: as colunas da primeira (%d) devem ser iguais às linhas da segunda (%d)",

        a.linhas, a.colunas, b.linhas, b.colunas, a.colunas, b.linhas), 2)

    end

    local meio = a.colunas

    return Matriz.nova(a.linhas, b.colunas, function(i, j)

      local soma, linha_a = 0, a[i]

      for k = 1, meio do soma = soma + linha_a[k] * b[k][j] end

      return soma

    end)

  end

  error("multiplicação inválida: use matriz * matriz, matriz * número ou número * matriz", 2)

end



-- matriz / número

---@param a Matriz
---@param b number Escalar diferente de zero.
---@return Matriz resultado
function Matriz.__div(a, b)

  if eh_matriz(a) and type(b) == "number" then

    if b == 0 then error("divisão de matriz por zero", 2) end

    return a:map(function(v) return v / b end)

  end

  error("divisão inválida: só existe matriz / número (para 'dividir' por uma matriz use B:inversa())", 2)

end



-- matriz ^ inteiro:  A ^ 0 = identidade,  A ^ 3 = A*A*A,  A ^ -1 = inversa

---Eleva uma matriz quadrada a um expoente inteiro; expoentes negativos usam a inversa.
---@param m Matriz
---@param n integer Expoente inteiro.
---@return Matriz resultado
function Matriz.__pow(m, n)

  if not eh_matriz(m) or type(n) ~= "number" or n ~= math.floor(n) or math.abs(n) == math.huge then

    error("potência inválida: use matriz ^ inteiro (por exemplo A ^ 3 ou A ^ -1)", 2)

  end

  exigir_quadrada(m, "a potência")



  local base = m

  if n < 0 then

    local inversa, motivo = inverter(m)

    if not inversa then error(motivo, 2) end

    base, n = inversa, -n

  end



  local resultado = Matriz.identidade(m.linhas)

  while n > 0 do                                   -- exponenciação por quadrados

    if n % 2 == 1 then resultado = resultado * base end

n = math.floor(n / 2)

    if n > 0 then base = base * base end

  end

  return resultado

end



-- ---------------------------------------------------------------------------

-- Métodos

-- ---------------------------------------------------------------------------



---Retorna a quantidade de linhas e de colunas.
---@param self Matriz
---@return integer linhas
---@return integer colunas
function Matriz:dimensoes()

  return self.linhas, self.colunas

end



---@param self Matriz
---@return boolean resultado
function Matriz:eh_quadrada()

  return self.linhas == self.colunas

end



---Verifica se a matriz é quadrada e simétrica por igualdade exata dos elementos.
---@param self Matriz
---@return boolean resultado
function Matriz:eh_simetrica()

  if not self:eh_quadrada() then return false end

  for i = 1, self.linhas do

    for j = i + 1, self.colunas do

      if self[i][j] ~= self[j][i] then return false end

    end

  end

  return true

end



-- Cópia independente (alterar a cópia não altera o original).

---Cria uma cópia independente da matriz.
---@param self Matriz
---@return Matriz copia
function Matriz:copiar()

  return Matriz.nova(self.linhas, self.colunas, function(i, j) return self[i][j] end)

end



-- Devolve uma tabela Lua comum: {{1, 2}, {3, 4}}

---Copia os dados para uma tabela Lua comum.
---@param self Matriz
---@return number[][] dados
function Matriz:para_tabela()

  local t = {}

  for i = 1, self.linhas do

    t[i] = {}

    for j = 1, self.colunas do t[i][j] = self[i][j] end

  end

  return t

end



-- Nova matriz com f(valor, i, j) aplicada a cada elemento.

---Aplica uma função a cada elemento e retorna uma nova matriz.
---@param self Matriz
---@param f fun(valor: number, linha: integer, coluna: integer): number
---@return Matriz resultado
function Matriz:map(f)

  return Matriz.nova(self.linhas, self.colunas, function(i, j) return f(self[i][j], i, j) end)

end



-- Iterador: for i, j, v in A:elementos() do ... end   (linha por linha)

---Retorna um iterador que produz linha, coluna e valor, nessa ordem.
---@param self Matriz
---@return fun(): integer, integer, number iterador
function Matriz:elementos()

  local i, j = 1, 0

  return function()

    j = j + 1

    if j > self.colunas then i, j = i + 1, 1 end

    if i > self.linhas then return nil end

    return i, j, self[i][j]

  end

end



-- Arredonda cada elemento para `casas` casas decimais (limpa coisas como 0.9999999999).

---Arredonda cada elemento para a quantidade de casas decimais indicada.
---@param self Matriz
---@param casas? integer Quantidade de casas decimais (padrão 0).
---@return Matriz resultado
function Matriz:arredondar(casas)

  local fator = 10 ^ (casas or 0)

  return self:map(function(v)

    local r = math.floor(v * fator + 0.5) / fator

    if r == 0 then r = 0 end  -- evita -0.0

    return r

  end)

end



-- Compara com tolerância (útil com números decimais).

---Compara duas matrizes usando uma tolerância numérica.
---@param self Matriz
---@param outra Matriz Matriz usada na comparação.
---@param tolerancia? number Diferença máxima permitida (padrão 1e-9).
---@return boolean resultado
function Matriz:aprox_igual(outra, tolerancia)

  if not eh_matriz(outra) or self.linhas ~= outra.linhas or self.colunas ~= outra.colunas then

    return false

  end

tolerancia = tolerancia or 1e-9

  for i, j, v in self:elementos() do

    if math.abs(v - outra[i][j]) > tolerancia then return false end

  end

  return true

end



-- Pedaço da matriz: linhas i1..i2 e colunas j1..j2 (inclusive).

---Extrai um intervalo inclusivo de linhas e colunas.
---@param self Matriz
---@param i1 integer Primeira linha.
---@param i2 integer Última linha.
---@param j1 integer Primeira coluna.
---@param j2 integer Última coluna.
---@return Matriz resultado
function Matriz:submatriz(i1, i2, j1, j2)

  if not (inteiro_positivo(i1) and inteiro_positivo(i2) and inteiro_positivo(j1) and inteiro_positivo(j2)

          and i1 <= i2 and j1 <= j2 and i2 <= self.linhas and j2 <= self.colunas) then

    error(string.format("submatriz(%s, %s, %s, %s) fora dos limites da matriz %dx%d",

      tostring(i1), tostring(i2), tostring(j1), tostring(j2), self.linhas, self.colunas), 2)

  end

  return Matriz.nova(i2 - i1 + 1, j2 - j1 + 1, function(i, j) return self[i1 + i - 1][j1 + j - 1] end)

end



---Retorna uma linha como uma matriz de uma linha.
---@param self Matriz
---@param i integer Índice da linha.
---@return Matriz resultado
function Matriz:pegar_linha(i)

  return self:submatriz(i, i, 1, self.colunas)

end



---Retorna uma coluna como uma matriz de uma coluna.
---@param self Matriz
---@param j integer Índice da coluna.
---@return Matriz resultado
function Matriz:pegar_coluna(j)

  return self:submatriz(1, self.linhas, j, j)

end



-- [A | B]  (lado a lado; precisa do mesmo número de linhas)

---Concatena duas matrizes lado a lado.
---@param self Matriz
---@param outra Matriz Matriz com a mesma quantidade de linhas.
---@return Matriz resultado
function Matriz:juntar_horizontal(outra)

  exigir_matriz(outra, "juntar_horizontal")

  if self.linhas ~= outra.linhas then

    error(string.format("juntar_horizontal exige o mesmo número de linhas (%d e %d)", self.linhas, outra.linhas), 2)

  end

  local n = self.colunas

  return Matriz.nova(self.linhas, n + outra.colunas, function(i, j)

    if j <= n then return self[i][j] end

    return outra[i][j - n]

  end)

end



-- A sobre B  (precisa do mesmo número de colunas)

---Concatena duas matrizes verticalmente.
---@param self Matriz
---@param outra Matriz Matriz com a mesma quantidade de colunas.
---@return Matriz resultado
function Matriz:juntar_vertical(outra)

  exigir_matriz(outra, "juntar_vertical")

  if self.colunas ~= outra.colunas then

    error(string.format("juntar_vertical exige o mesmo número de colunas (%d e %d)", self.colunas, outra.colunas), 2)

  end

  local n = self.linhas

  return Matriz.nova(n + outra.linhas, self.colunas, function(i, j)

    if i <= n then return self[i][j] end

    return outra[i - n][j]

  end)

end



-- Produto elemento a elemento (o * entre matrizes é o produto matricial).

---Multiplica os elementos correspondentes, sem produto matricial.
---@param self Matriz
---@param outra Matriz Matriz do mesmo tamanho.
---@return Matriz resultado
function Matriz:produto_elemento(outra)

  exigir_matriz(outra, "produto_elemento")

  exigir_mesmo_tamanho(self, outra, "o produto elemento a elemento")

  return Matriz.nova(self.linhas, self.colunas, function(i, j) return self[i][j] * outra[i][j] end)

end



---Retorna a transposta da matriz.
---@param self Matriz
---@return Matriz resultado
function Matriz:transposta()

  return Matriz.nova(self.colunas, self.linhas, function(i, j) return self[j][i] end)

end



---Calcula o traço de uma matriz quadrada.
---@param self Matriz
---@return number resultado
function Matriz:traco()

  exigir_quadrada(self, "o traço")

  local soma = 0

  for i = 1, self.linhas do soma = soma + self[i][i] end

  return soma

end



-- Norma de Frobenius: raiz da soma dos quadrados de todos os elementos.

---Calcula a norma de Frobenius.
---@param self Matriz
---@return number resultado
function Matriz:norma()

  local soma = 0

  for _, _, v in self:elementos() do soma = soma + v * v end

  return math.sqrt(soma)

end



---@return Matriz
function Matriz:soma_linhas()
    local somas = {}
    self:copiar():map(function(valor, linha, coluna)
        somas[coluna] = (somas[coluna] or 0) + valor
        return valor
    end)
    return Matriz.vetor_linha(somas)  -- tabela comum: {soma_col1, soma_col2, ...}
end



-- Determinante por eliminação de Gauss com pivotamento parcial.

-- Se não houver pivô (matriz singular), devolve 0.

---Calcula o determinante por eliminação de Gauss com pivotamento parcial.
---@param self Matriz Matriz quadrada.
---@return number determinante
function Matriz:determinante()

  exigir_quadrada(self, "o determinante")

  local n = self.linhas

  local a = self:copiar()

  local tol = Matriz.tolerancia * maior_modulo(self)

  local det = 1



  for c = 1, n do

    local p, maior = c, math.abs(a[c][c])

    for i = c + 1, n do

      local v = math.abs(a[i][c])

      if v > maior then p, maior = i, v end

    end

    if maior <= tol then return 0 end  -- coluna sem pivô: matriz singular

    if p ~= c then

      a[p], a[c] = a[c], a[p]

      det = -det                        -- trocar duas linhas inverte o sinal

    end

    det = det * a[c][c]

    for i = c + 1, n do

      local f = a[i][c] / a[c][c]

      if f ~= 0 then

        for j = c, n do a[i][j] = a[i][j] - f * a[c][j] end

      end

    end

  end

  return det

end



---Calcula a inversa; lança erro se a matriz for singular.
---@param self Matriz Matriz quadrada e invertível.
---@return Matriz inversa
function Matriz:inversa()

  exigir_quadrada(self, "a inversa")

  local inv, motivo = inverter(self)

  if not inv then error(motivo, 2) end

  return inv

end



-- Posto (rank): quantidade de linhas linearmente independentes.

---Calcula o posto (rank) da matriz.
---@param self Matriz
---@return integer posto
function Matriz:posto()

  local a = self:copiar()

  local tol = Matriz.tolerancia * maior_modulo(self)

  local posto, atual = 0, 1



  for c = 1, a.colunas do

    if atual > a.linhas then break end

    local p, maior = atual, math.abs(a[atual][c])

    for i = atual + 1, a.linhas do

      local v = math.abs(a[i][c])

      if v > maior then p, maior = i, v end

    end

    if maior > tol then

      a[p], a[atual] = a[atual], a[p]

      for i = atual + 1, a.linhas do

        local f = a[i][c] / a[atual][c]

        for j = c, a.colunas do a[i][j] = a[i][j] - f * a[atual][j] end

      end

      atual, posto = atual + 1, posto + 1

    end

  end

  return posto

end



-- Resolve A·x = b. O b pode ser uma matriz (n x k) ou uma lista simples {5, 10}.

-- Devolve x como matriz (coluna).

---Resolve A·x = b para uma matriz quadrada A.
---@param self Matriz Matriz dos coeficientes, quadrada.
---@param b Matriz|number[] Vetor de constantes ou matriz com uma ou mais colunas.
---@return Matriz solucao Matriz de soluções, uma coluna por sistema resolvido.
function Matriz:resolver(b)

  exigir_quadrada(self, "resolver o sistema")

  if not eh_matriz(b) then

    if type(b) ~= "table" then

      error("resolver espera uma matriz ou uma lista de números", 2)

    end

b = Matriz.vetor_coluna(b)

  end

  if b.linhas ~= self.linhas then

    error(string.format("o lado direito tem %d linhas, mas a matriz tem %d", b.linhas, self.linhas), 2)

  end

  local x, motivo = resolver_sistema(self, b)

  if not x then error(motivo, 2) end

  return x

end



-- ---------------------------------------------------------------------------

-- Exemplos (rodam só com:  lua matriz.lua)

-- ---------------------------------------------------------------------------



local function exemplos()

  local function secao(titulo) print("\n=== " .. titulo .. " ===") end

  local function num(x) return string.format("%g", x) end  -- imprime 2.0 como 2



  math.randomseed(42)



  secao("1. Criando matrizes")

  local A = Matriz{{1, 2}, {3, 4}}

  local B = Matriz{{0, 1}, {1, 0}}

  print("A =\n" .. A)

  print("B =\n" .. B)

  print("identidade 3x3 =\n" .. Matriz.identidade(3))

  print("zeros 2x3 =\n" .. Matriz.zeros(2, 3))

  print("nova(3, 3, i + j) =\n" .. Matriz.nova(3, 3, function(i, j) return i + j end))

  print("diagonal {2, 5, 7} =\n" .. Matriz.diagonal({2, 5, 7}))

  print("aleatória 2x3 (valores de 1 a 6) =\n" .. Matriz.aleatoria(2, 3, 1, 6))



  secao("2. Lendo e alterando elementos")

  local C = A:copiar()

  print("A[2][1] =", A[2][1])

  print("A(1, 2) =", A(1, 2), "(leitura com checagem de limites)")

  C[1][1] = 10

  print("C depois de C[1][1] = 10:\n" .. C)

  print("A continua igual (copiar faz cópia independente):\n" .. A)

  print("tamanho de A:", A:dimensoes())



  secao("3. Operadores")

  print("A + B =\n" .. (A + B))

  print("A - B =\n" .. (A - B))

  print("A * B (produto de matrizes) =\n" .. (A * B))

  print("2 * A =\n" .. (2 * A))

  print("A / 2 =\n" .. (A / 2))

  print("-A =\n" .. (-A))

  print("A ^ 3 =\n" .. (A ^ 3))

  print("A == Matriz(A) ?", A == Matriz(A))

  print("A == B ?", A == B)

  print("#A (número de linhas) =", #A)



  secao("4. Transposta, traço, determinante e inversa")

  print("A transposta =\n" .. A:transposta())

  print("traço de A =", A:traco())

  print("det(A) =", num(A:determinante()))

  print("A inversa =\n" .. A:inversa())

  print("A * A^-1 =\n" .. (A * A:inversa()):arredondar(10))

  print("A ^ -1 igual a A:inversa() ?", (A ^ -1):aprox_igual(A:inversa()))

  print("norma de A =", num(A:norma()))



  secao("5. Sistema linear")

-- 2x +  y =  5

--  x + 3y = 10      ->  x = 1, y = 3

  local S = Matriz{{2, 1}, {1, 3}}

  local x = S:resolver({5, 10})

  print("solução (x, y) =\n" .. x)

  print("conferindo S * solução =\n" .. (S * x):arredondar(10))



  secao("6. Posto e matriz singular")

  local D = Matriz{{1, 2, 3}, {4, 5, 6}, {7, 8, 9}}

  print("posto de D =", D:posto())

  print("det(D) =", num(D:determinante()))

  local ok, erro = pcall(D.inversa, D)

  print("D:inversa() funcionou?", ok)

  print("erro:", erro)



  secao("7. Erros com mensagens claras")

  local function tentar(f)

    local _, e = pcall(f)

    print("erro: " .. tostring(e))

  end

  tentar(function() return A + Matriz.zeros(3, 3) end)

  tentar(function() return A * Matriz.zeros(3, 3) end)

  tentar(function() A[1][5] = 99 end)

  tentar(function() return A(3, 1) end)

  tentar(function() return Matriz.zeros(2, 3):determinante() end)

  tentar(function() return A / 0 end)



  secao("8. Percorrendo, transformando e montando")

  for i, j, v in B:elementos() do

    print(string.format("B[%d][%d] = %s", i, j, tostring(v)))

  end

  print("quadrado de cada elemento de A =\n" .. A:map(function(v) return v * v end))

  print("linha 2 de D =\n" .. D:pegar_linha(2))

  print("coluna 3 de D =\n" .. D:pegar_coluna(3))

  print("submatriz de D (linhas 1-2, colunas 2-3) =\n" .. D:submatriz(1, 2, 2, 3))

  print("A | B (lado a lado) =\n" .. A:juntar_horizontal(B))

  print("A sobre B =\n" .. A:juntar_vertical(B))

  print("A .* B (elemento a elemento) =\n" .. A:produto_elemento(B))

  print("A é simétrica?", A:eh_simetrica())

  print("A + A^T é simétrica?", (A + A:transposta()):eh_simetrica())

end



-- Os exemplos só rodam quando o arquivo é executado direto (lua matriz.lua).

-- Com require("matriz") o Lua passa o nome do módulo em "...", e aí eles não rodam.

if select("#", ...) == 0 then

  exemplos()

end



return Matriz
