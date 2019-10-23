# Como debuggar UPFs do ANSYS no Visual Studio
Aqui vão algumas explicações sobre como editar o arquivo de compilação do ANSYS para ativar o debug e como conectar o debbuger do Visual Studio ao ANSYS. **Esse tutorial aborda apenas os passos para debuggar UPFs programadas em FORTRAN compiladas na forma `.dll`, através do arquivo `ANSUSERSHARED.bat`. Para debuggar UPFs que compõem um novo executável o procedimento é semelhante, entretanto devem ser alterados outros arquivos que compõem a compilação e linkagem, em caso de duvida basta entrar em contato. :smile:**


## Parte 0: Arquivos prontos:
Estou disponibilizando aqui algumas versões do arquivo de compilação com o debug ativado para certas versões (as que tive acesso), quem trabalhar com outras versões pode me enviar seu `ANSUSERSHARED.bat` que faço as alterações e anexo aqui, também aceito as versões editadas. Quem for usar um desses arquivos prontos pode pular diretamente para a parte 2 do tutorial.
- [Debug ANSYS v194](https://github.com/dutitello/debug-ansys-upf/)

## Parte 1: Edição do arquivo de compilação:
**Para ativar o debug algumas bandeiras de compilação e linkagem das UPFs devem ser alteradas, tais alterações envolvem desativar a otimização do código compilado e outras, reduzindo a eficiencia do código compilado. É recomendado então manter uma versão original do arquivo para realização das análises, após desenvolvimento da UPF.**

1) Abrir a cópia do arquivo `ANSUSERSHARED.bat` em um editor de texto.

2) Encontrar as chamadas do compilador Intel Fortran, `ifort`: dependendo da versão do ANSYS o comando `ifort` estará em um laço `IF` ou `DO`, independentemente disso logo após `ifort` devem ser adicionado os seguintes comandos `/debug /Zi /warn:all /check:all /traceback /Qfp-stack-check /Od /wrap-margin-`, mantendo os demais comandos, por exemplo:
- Original (v194): `if exist *.F ( ifort %COMMACS% %FMACS% %COMSWITCH% %FSWITCH% %MACS64% *.F   >>compile.log 2>&1 )`  
- Novo (v194):  `if exist *.F ( ifort /debug /Zi /warn:all /check:all /traceback /Qfp-stack-check /Od /wrap-margin- %COMMACS% %FMACS% %COMSWITCH% %FSWITCH% %MACS64% *.F   >>compile.log 2>&1 )`
**Obs.:** `/wrap-margin-` é opcional, serve para que a escrita de arquivos de texto do FORTRAN não tenha limite de colunas.

3) Removendo chamada de otimizador: originalmente o código é compilado de forma otimizada, entretanto isso pode produzir problemas durante o debug, o trecho `/Od` no passo anterior desativa a otimização, entretanto deve ser removido trecho em que a otimização é originalmente ativada, evitando conflitos, para isso as ocorrências de `/O2` no arquivo devem ser removidas, por exemplo:
- Original (v194): `set "COMSWITCH=/O2 /MD /c"`  
- Novo (v194):  `set "COMSWITCH=/MD /c"`

4) Desativando a exclusão automática do arquivo `compile_error.txt`: as bandeiras inseridas no compilador anteriormente irão emitir todo e qualquer aviso de compilação, ~~por mais inutil que seja~~, assim é útil manter o arquivo que isola os erros, para isso remova qualquer ocorrência de `del /Q compile_error.txt`.

5) Adicionando flag de debug no linker: o arquivo `ANSUSERSHARED.bat` cria um arquivo `.lrf` com comandos do linker, para encontrar a criação desse arquivo deve ser encontrado o trecho com a linha `echo -dll>>%UPFFILE%.lrf` (por exemplo), nessa região haverão diversas linhas no formato `echo -[...]>>%UPFFILE%.lrf`, entre quaisquer duas linhas nesse formato deve ser adicionada a linha `echo -debug>>%UPFFILE%.lrf`.
