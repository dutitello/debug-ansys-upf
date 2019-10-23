# Como debuggar UPFs do ANSYS no Visual Studio
Aqui vão algumas explicações sobre como editar o arquivo de compilação do ANSYS para ativar o debug e como conectar o debbuger do Visual Studio ao ANSYS. **Esse tutorial aborda apenas os passos para debuggar UPFs na forma `.dll`, através do arquivo `ANSUSERSHARED.bat`, para debuggar UPFs que compõem um novo executável o procedimento é semelhante, entretanto devem ser alterados outros arquivos que compõem a compilação e linkagem, em caso de duvida basta entrar em contato. :smile:**


## Parte 0: Arquivos prontos:
Estou disponibilizando aqui algumas versões do arquivo de compilação com o debug ativado para certas versões (as que tive acesso), quem trabalhar com outras versões pode me enviar seu `ANSUSERSHARED.bat` que faço as alterações e anexo aqui, também aceito as versões editadas. Quem for usar um desses arquivos prontos pode pular diretamente para a parte 2 do tutorial.
- [Debug ANSYS v194](https://github.com/dutitello/debug-ansys-upf/)

## Parte 1: Edição do arquivo de compilação:
**Para ativar o debug algumas bandeiras de compilação e linkagem das UPFs devem ser alteradas, tais alterações envolvem desativar a otimização do código compilado e outras, reduzindo a eficiencia do código compilado. É recomendado então manter uma versão original do arquivo para realização das análises, após desenvolvimento da UPF.**
