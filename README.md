# Interpretador

Interpretador de uma linguagem ficticia desenvolvida na linguagem de programação LUA, baseando-se em uma BNF (Formalismo de Backus-Naur).

Realizado a implementação das expressões regulares (Regex), que são utilizadas para obter informações do código a ser interpretado, essas expressões correspondem a sintaxe da linguagem Bpl. A ideia abordada visa dividir o código em expressões para assim conseguir extrair todas as informações necessárias para o interpretador, algumas dessas expressões foram divididas em partes menores que se repetem para assim simplificar e facilitar a legibilidade do programa, um exemplo ocorre no caso da expressão de atribuição, onde duas expressões são usadas para compor uma nova expressão.


Tratamento de variáveis, sendo que para elas é necessário verificar declarações, passagem de 1 parâmetros, verificação de escopo e recuperação de valores. Atriuições de valores em variáveis, valores esses que podem ser constantes numéricas, valores contidos em outras variáveis ou obtidos através de operações aritméticas, e chamada de funções, que precisam ter seus parâmetros resolvidos antes que a chamada ocorra.

