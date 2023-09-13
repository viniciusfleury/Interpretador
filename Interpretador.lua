--[[
		Pega o nome do arquivo passado como parâmetro (se houver)
]]
local filename = ...
if not filename then
   print("Usage: lua interpretador.lua <prog.bpl>")
   os.exit(1)
end

local file = io.open(filename, "r")
if not file then
   print(string.format("[ERRO] Cannot open file %q", filename))
   os.exit(1)
end

--[[
		Declaração dos pattern's que são utilizados
]]
local header	= "%s*function%s+(%a+)%(([^%)]*)%)"
local vardef	= "%s*var%s+(%a+)%[?(%d*)%]?"
local funcall	= "^%s*(%a+)%(([^%)]*)%)"
local var		= "([%-%a%d]*)[%(%[]?([%-%d%a%,]*)[%]%)]?"
local op		= "([%+%-%*%/]?)"
local attr		= var.."%s+=%s+"..var.."%s*"..op.."%s*"..var
local valor		= "([%-%a%d]+)%[*([%-%d]*)%]*"
local cmp		= "([%<%>%!%=]+)"
local ifcmp		= "if%s+"..valor.."%s+"..cmp.."%s+"..valor.."%s+then"
local begin		= "^%s*begin%s*"

--[[
		Declaração da variavel que guarda as 
		instancias das funções do programa
]]
local memory = {}
memory.print = print

--		Variaveis que auxiliam na leitura das funcoes
local nomeFuncao
local nomeParams

--[[
		Captura o momento em que cada funcao aparece no arquivo
]]
for line in file:lines() do
	funcNome, parametros = string.match(line, header)
	if funcNome ~= nil then
		-- #line retorna o tamanho da linha sem o '\n'
		memory[funcNome] = file:seek() - (#line + 1)	
	end
end

--[[
		Esta funcao muda seu tipo de retorno de acordo com os parametros
		Se attr for nil entao o retorno é o valor contido na var procurada
		Se a variavel procurada nao existir o retorno da funcao é nil
		Se attr possui um valor o retorno da funcao é nil
]]
function resolveEscopo(tVar, lVal, ilVal, attr)
	--procura a variavel na pilha: tVar
	repeat
		--enquanto nao achar a variavel passa para proxima pilha
		if not tVar[lVal]  then
			tVar = tVar.PROX
		else
			--encontrou a variavel, verifica se possui indice
			if ilVal ~= nil then
				if ilVal <= 0 then
					--corigindo indice negativo
					ilVal = tVar[lVal].size + ilVal
				end
				if ilVal > tVar[lVal].size then
					print(string.format("[ERRO] Invalid array index"))
					file:close()
					os.exit(1)
				end
			end
			
			if not attr then
				if not ilVal then
					return tVar[lVal]
				else
					return tonumber(tVar[lVal][ilVal])
				end
			else
				if not ilVal then
					tVar[lVal] = attr
				else
					tVar[lVal][ilVal] = attr
				end
				return nil
			end
		end
	until not tVar
	--retorno nil diz que é uma atribuição ou que a var nao foi encontrada
	return nil
end

--arg: nome da variavel ou uma constante(string), iarg: indice da variavel(int), tVar: tabela com as variaves do programa(table)
function resolveArg(arg, iarg, tVar)
	--verifica se é numero, se resolveEscopo retorna nil entao arg é um numero
	if not resolveEscopo(tVar, arg) then
		return tonumber(arg)
	else
		iarg = tonumber(iarg)
		if iarg ~= nil then
			iarg = iarg + 1		--existe indice e corige o indice começado em zero
		end
		return resolveEscopo(tVar, arg, iarg)
	end
end
--[[
		Funcao responsavel por interpretar a chamada de uma funcao no codigo
		O retorno dessa funcao corresponde ao retorno da função interpretada
]]
function resolveFuncao(funcNome, parametros, tVar, tParam)
	--	pega linha do arquivo para que interpretador possa voltar
	--	ao ponto correto do arquivo que estava executando
	local rip = file:seek()
	local resParam = {}			--vetor para auxiliar resolução dos parametros
	local ret = 0
	
	--	Apos executar este laço todas variaveis tem seu valor recuperado
	--	e sao colocados no vetor resParam
	--	value possui o nome da variavel e key seu indice
	for value,key in string.gmatch(parametros, valor) do
		if #key == 0 then
			if not resolveEscopo(tParam, value) then
				if not resolveEscopo(tVar, value) then
					resParam[#resParam+1] = tonumber(value)
				else
					resParam[#resParam+1] = resolveEscopo(tVar, value)
				end
			else
				resParam[#resParam+1] = resolveEscopo(tParam, value)
			end
		else
			resParam[#resParam+1] = resolveEscopo(tVar, value, tonumber(key))
		end
	end
	
	parametros = ""
	--	Apos executar este laço parametros contem os valores ja calculados
	--	de forma que execFunc possa executar de forma correta
	--	key possui o indice do vetor e value contem o valor na posicao
	for key,value in ipairs(resParam) do
		parametros = parametros..value
		if key ~= #resParam then
			parametros = parametros..','
		end
	end
	
	ret = execFunc(memory[funcNome], parametros, tVar)
	--		Apos executar a funcao é necessario voltar ao ponto que o arquivo 
	--		estava, assim continuando o fluxo normal do interpretador
	file:seek("set", rip)
	return ret
end

--[[
		Esta funcao é responsavel por interpretar funções contidas no codigo
		Seu retorno é resultado da parte do codigo interpretado
		Ela encerra ao encontrar um "end" no codigo
]]
function execFunc(linha, param, pilha)
	--leva para o inicio da função chamada
	file:seek("set", linha)
	
	--	variaveis de captura do programa
	local funcNome		--recebe nome da funcao
	local parametros	--recebe o conjunto de paramentros
	local defVar		--nome da variavel declarada
	local sizeVar		--tamanho do vetor
	local lVal			--valor esq. na atribuição
	local ilVal			--indice da var. caso seja vetor
	local arg1			--primeiro valor direito
	local iArg1			--indice da var. agr1 caso seja um vetor
	local arg2			--segundo valor direito
	local iArg2			--indice da var. agr2 caso seja um vetor
	local oper			--operação para atribuição ou comparação no if
	local inicio		--captura inicio do corpo da função(begin)
	local senao			--captura fim de um if ou um else
	local fim			--captura fim	 do corpo da função(end)
	local flagif = nil	--flag para verificação do if
	--				observações
	--	funcNome e paramentro servem para declaração e chamada de função
	--	arg1, iArg1, oper, arg2 e iArg2 servem para atribuição e comparação
	
	--	table é uma tabela que armazena todas as variaveis criadas na função
	local table = {}
	table.PROX = pilha
	table.ret = 0
	
	--	tParam é uma tabela que armazena todas as variaveis de parametro
	local tParam = {}
	
	--	line recebe uma função iteradora para percorrer o arquivo
	--	str é uma variavel auxiliar utilizada para receber as linhas lidas do arquivo
	line = file:lines()
	local str = line()
	
	funcNome, parametros = string.match(str, header)
	
	-- instancia dos parametros
	if #param ~= 0 and #parametros ~=0 then
		local nomeVar = string.gmatch(parametros, "[^,]+")	--funcao iteradora que retorna os parametros
		for value in string.gmatch(param, "[^,]+") do		--os valores recebido em param ja estão convertidos em numeros inteiros
			tParam[nomeVar()] = tonumber(string.match(value, "([%-%d]*)"))
		end
	end
	
	-- instancia da variaveis da função
	str = line()
	--verifica se a linha corresponde a um begin
	inicio = string.match(str, begin)
	if inicio == nil then
		defVar, sizeVar = string.match(str, vardef)
		repeat
			if #sizeVar == 0 then
				table[defVar] = 0
			else
				table[defVar] = {}
				table[defVar].size = tonumber(sizeVar)
				for i = 1, table[defVar].size do
					table[defVar][i] = 0
				end
			end
			str = line()
			defVar, sizeVar = string.match(str, vardef)
		until defVar == nil
	end
	
	--	incio do corpo da função
	str = line()
	fim = string.match(str, "%s*(end)%s*")
	
	--repita ate encontrar linha com end
	while fim ~= "end" do
		--	ar1 e ar2 sao responsaveis por guardar os argumentos
		--	utilizados em atribuições e comparacoes
		local ar1, ar2
		
		--	captura informação para validar se é atribuição
		lVal, ilVal, arg1, iArg1, oper, arg2, iArg2 = string.match(str, attr)
		if lVal ~= nil then
			--	verifica se é uma função
			--	se memory[arg1] retornar nil então é uma variável
			if not memory[arg1] then
				--	se a var. nao esta nos parametros
				if not tParam[arg1] then
					ar1 = resolveArg(arg1, iArg1, table)
				else
					ar1 = resolveArg(arg1, iArg1, tParam)
				end
			else
				ar1 = resolveFuncao(arg1, iArg1, table, tParam)
			end
			
			ilVal = tonumber(ilVal)
			if ilVal ~= nil then
				ilVal = ilVal + 1		--existe indice e corige o indice começado em zero
			end
			
			if #oper == 0 then
				if not tParam[lVal] then
					resolveEscopo(table, lVal, ilVal, ar1)
				else
					resolveEscopo(tParam, lVal, ilVal, ar1)
				end
			else
				--	verifica se é uma função
				--	se memory[arg2] retornar nil então é uma variável ou numero
				if not memory[arg2] then
					--	se a var. nao esta nos parametros
					if not tParam[arg2] then
						ar2 = resolveArg(arg2, iArg2, table)
					else
						ar2 = resolveArg(arg2, iArg2, tParam)
					end
				else
					ar2 = resolveFuncao(arg2, iArg2, table, tParam)
				end
				
				if oper == '+' then
					if not tParam[lVal] then
						resolveEscopo(table, lVal, ilVal, ar1 + ar2)
					else
						resolveEscopo(tParam, lVal, ilVal, ar1 + ar2)
					end
				elseif oper == '-' then
					if not tParam[lVal] then
						resolveEscopo(table, lVal, ilVal, ar1 - ar2)
					else
						resolveEscopo(tParam, lVal, ilVal, ar1 - ar2)
					end
				elseif oper == '*' then
					if not tParam[lVal] then
						resolveEscopo(table, lVal, ilVal, ar1 * ar2)
					else
						resolveEscopo(tParam, lVal, ilVal, ar1 * ar2)
					end
				else
					if not tParam[lVal] then
						resolveEscopo(table, lVal, ilVal, math.floor(ar1/ar2))
					else
						resolveEscopo(tParam, lVal, ilVal, math.floor(ar1/ar2))
					end
				end
			end
		--		fim do bloco de atribuição
		else
		--		captura informação para validar se é chamada de função
			funcNome, parametros = string.match(str, funcall)
			if funcNome ~= nil then
				--	se nao for a função print chama recursivamente execFunc
				if funcNome ~= "print" then
					resolveFuncao(funcNome, parametros, table, tParam)
				else
					if not string.match(parametros, "%a+") then		--caso parametro seja um numero
						memory[funcNome](tonumber(parametros))
					else
						--	var. locais desse bloco else
						local value
						local indice
						value, indice = string.match(parametros, "(%a+)%[?([%-%d]*)%]?")
						
						if not tParam[value] then
							memory[funcNome](resolveArg(value, indice, table))
						else
							memory[funcNome](resolveArg(value, indice, tParam))
						end
					end
				end
			--		fim do bloco de chamada de função
			else
			--		captura informação para validar se é uma comparação
				arg1, iArg1, oper, arg2, iArg2 = string.match(str, ifcmp)
				
				if not tParam[arg1] then
					ar1 = resolveArg(arg1, iArg1, table)
				else
					ar1 = resolveArg(arg1, iArg1, tParam)
				end
				if not tParam[arg2] then
					ar2 = resolveArg(arg2, iArg2, table)
				else
					ar2 = resolveArg(arg2, iArg2, tParam)
				end
				
				if arg1 ~= nil then
					flagif = false
					--caso alguma das comparações forem falsas nao é necessário mudar valor da flag
					if oper == "<" then
						if ar1 < ar2 then
							flagif = true
						end
					elseif oper == "<=" then
						if ar1 <= ar2 then
							flagif = true
						end
					elseif oper == ">" then
						if ar1 > ar2 then
							flagif = true
						end
					elseif oper == ">=" then
						if ar1 >= ar2 then
							flagif = true
						end
					elseif oper == "==" then
						if ar1 == ar2 then
							flagif = true
						end
					else
						if ar1 ~= ar2 then
							flagif = true
						end
					end
					--	caso seja falso, roda uma iteração e ignora
					--	a linha de atribuicao dentro do if
					if not flagif then
						str = line()
					end
				end
				senao = string.match(str, "%s*(else)%s*")
				--	caso flag seja verdadeira, roda uma iteração
				--	e ignora a linha de atribuicao dentro do else
				if senao == "else" and flagif then
					str = line()
					flagif = false
				end
			end
		end
		
		str = line()
		fim = string.match(str, "%s*(end)%s*")
	end
	return table.ret
end

execFunc(memory["main"], "")
file:close()
