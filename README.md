# Como debuggar UPFs do ANSYS no Visual Studio
Aqui vão algumas explicações sobre como editar o arquivo de compilação do ANSYS para ativar o debug e como conectar o debbuger ~~(ou depurrador, wtf?)~~ do Visual Studio ao ANSYS. **Esse tutorial aborda apenas os passos para debuggar UPFs programadas em FORTRAN compiladas na forma `.dll`, através do arquivo `ANSUSERSHARED.bat`. Para debuggar UPFs que compõem um novo executável o procedimento é semelhante, entretanto devem ser alterados outros arquivos que compõem a compilação e linkagem, em caso de duvida basta entrar em contato. :smile:**


## Parte 0: Arquivos prontos:
Estou disponibilizando aqui algumas versões do arquivo de compilação com o debug ativado para certas versões (as que tive acesso), quem trabalhar com outras versões pode me enviar seu `ANSUSERSHARED.bat` que faço as alterações e anexo aqui, também aceito as versões editadas. Quem for usar um desses arquivos prontos pode pular diretamente para a parte 2 do tutorial.
- [Debug ANSYS v194](https://github.com/dutitello/debug-ansys-upf/raw/master/bats/debug194.bat)

## Parte 1: Edição do arquivo de compilação:
**Para ativar o debug algumas bandeiras de compilação e linkagem das UPFs devem ser alteradas, tais alterações envolvem desativar a otimização do código compilado e outras, reduzindo a eficiencia do código compilado. É recomendado então manter uma versão original do arquivo para realização das análises, após desenvolvimento da UPF.**

1) Abrir a **cópia** do arquivo `ANSUSERSHARED.bat` em um editor de texto.

2) Encontrar as chamadas do compilador Intel Fortran (`ifort`): dependendo da versão do ANSYS o comando `ifort` estará em um laço `IF` ou `DO`, independentemente disso logo após `ifort` devem ser adicionado os seguintes comandos `/debug /Zi /warn:all /check:all /traceback /Qfp-stack-check /Od /wrap-margin-`, mantendo os demais comandos, por exemplo:

    - Original (v194): `if exist *.F ( ifort %COMMACS% %FMACS% %COMSWITCH% %FSWITCH% %MACS64% *.F   >>compile.log 2>&1 )`.

    - Novo (v194):  `if exist *.F ( ifort /debug /Zi /warn:all /check:all /traceback /Qfp-stack-check /Od /wrap-margin- %COMMACS% %FMACS% %COMSWITCH% %FSWITCH% %MACS64% *.F   >>compile.log 2>&1 )`.
    
    **Obs.:** `/wrap-margin-` é opcional, serve para que a escrita de arquivos de texto do FORTRAN não tenha limite de colunas.

3) Removendo chamada de otimizador: originalmente o código é compilado de forma otimizada, entretanto isso pode produzir problemas durante o debug, o trecho `/Od` no passo anterior desativa a otimização, entretanto deve ser removido trecho em que a otimização é originalmente ativada, evitando conflitos, para isso as ocorrências de `/O2` no arquivo devem ser removidas, por exemplo:

    - Original (v194): `set "COMSWITCH=/O2 /MD /c"` 

    - Novo (v194):  `set "COMSWITCH=/MD /c"`

4) Desativando a exclusão automática do arquivo `compile_error.txt`: as bandeiras inseridas no compilador anteriormente irão emitir todo e qualquer aviso de compilação, ~~por mais inutil que seja~~, assim é útil manter o arquivo que isola os erros, para isso remova qualquer ocorrência de `del /Q compile_error.txt` realizada após o comando `ifort`, caso seja também removida a ocorrencia anterior a `ifort` serão acumulados erros entre diferentes execuções.

5) Adicionando flag de debug no linker: o arquivo `ANSUSERSHARED.bat` cria um arquivo `.lrf` com comandos do linker, para encontrar a criação desse arquivo deve ser encontrado o trecho onde diversas linhas começam no formato `echo -[...]>>[...]`, como por exemplo `echo -dll>>%LRFFILE%`. Entre quaisquer duas linhas nesse trecho deve ser criada uma nova linha com o comando `-debug`, diferentes versões do ANSYS usam diferentes formatos para a criação do arquivo `.lrf`, assim recomendo que seja copiada a linha com o comando `-dll` e este seja trocado por `-debug`. Na versão 194, por exemplo, a linha a ser inserida é `echo -debug>>%LRFFILE%`, enquanto na versão 170 era `echo -debug>>%UPFFILE%.lrf`.

**Observações gerais:**
    Após a compilação da UPF através do novo arquivo `ANSUSERSHARED.bat` serão gerados diversos arquivos na pasta de trabalho que não apareciam anteriormente (`.obj, .mod, .f90, .pdb, .ilk`), alguns destes contem informações relevantes ao debbuger, então devem ser mantidos durante o processo de debug.


## Parte 2: Conectando o debbuger do Visual Studio ao ANSYS: 
Após compilar a UPF através do arquivo gravado na Parte 1 o processo de debug deve ser realizado da seguinte forma:
1) Iniciar o ANSYS, sem executar nenhum comando, por enquanto.
2) Abrir Visual Studio e anexar o ANSYS ao debbuger do programa: 

    2.1) A lista de processos pode ser aberta através do comando `Ctrl+Alt+P` ou conforme apresentado nas figuras a seguir:

        ![](/util/attach1.png)
        ![](/util/attach2.png)

    2.2) Na lista de processos deve ser selecionado o processo `ANSYS.exe`, além de garantir que os demais itens estejam de acordo com a imagem a seguir:

        ![](/util/attach3.png)

    2.3) Com o processo anexado deve ser verificado se os simbolos de debug foram carregados: na aba Output do Debug do Visual Studio haverá uma lista de 'partes do ANSYS' carregadas pelo sistema, em uma destas linhas haverá o diretório onde está a UPF compilada e seu nome, sendo a linha finalizada por `Symbols loaded.`, caso a linha seja finalizada como `Module was built without symbols.` o arquivo de compilação deve estar incompleto ou está faltando algum arquivo `.pdb` na pasta de execução da UPF. Na figura a seguir é ilustrado carregamento da UPF `UserMat` na pasta `C:\ANSYS\UPF Compilar\usermat-ansys\`.
    
        ![](/util/symload.png)

3) Abrir o arquivo fonte de UPF em questão no Visual Studio, este deve estar na pasta da `dll` criada.

4) O processo de debug agora pode ser realizada de forma usual, ~primeiramente~ devem ser criados os breakpoints no código da UPF e então devem ser executados os comandos de análise do ANSYS de maneira tradicional, no momento em que o programa estiver usando a UPF em questão e atingir o breakpoint em questão o Visual Studio passará ao primeiro plano da tela. 

Obs.: Usando a versão 17 do Visual Studio (ANSYS 194) existe um bug entre o Visual Studio e o Intel Fortran onde não é possível acesssar matrizes/vetores durante o debug e o Visual Studio fecha em alguns momentos. A Intel lançou um patch de correção pra isso, se for o seu caso [clique aqui para maiores informações](https://software.intel.com/en-us/articles/fortran-debugger-in-microsoft-visual-studio-2017-crashes-does-not-show-arrays).

