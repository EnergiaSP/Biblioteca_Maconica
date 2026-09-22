# Biblioteca Maconica

Repositorio privado dos projetos atuais iOS e Android da Biblioteca Maconica.
Versao de desenvolvimento: 1.0.15. Este envio nao publica aplicativos nas lojas.

## Organizacao

- `BibliotecaMaconica_Dev/`: aplicativo iOS, widget, watchOS, recursos e testes.
- `projetos/BreviarioMaconicoAndroid/`: aplicativo Android, Wear OS e testes.
- `Paridade/`: contrato de paridade, casos comuns, regras de estudo e relatorios.
- `Tools/`: verificadores, comparadores e ferramentas compartilhadas.

Comece por `Paridade/RELATORIO_FILTROS_ACESSIBILIDADE_2026-09-22.md`.
A auditoria funcional ainda tem pendencias. Nao declarar equivalencia operacional
integral nem publicar enquanto os criterios do contrato nao forem atendidos.

## Desenvolvimento

No Xcode, abrir `BibliotecaMaconica_Dev/BreviarioMaconicoXXI.xcodeproj`.
No Android Studio, abrir `projetos/BreviarioMaconicoAndroid`.
O Android utiliza JDK 17. Consulte os arquivos Gradle para as versoes do SDK e
das dependencias. Os scripts locais podem depender de runtimes em `.tools/`,
que nao sao distribuidos neste repositorio; configure-os na maquina de destino.

Para conferir recursos, regras, versoes e contrato compartilhados:

```sh
bash Tools/verificar_paridade.sh
bash Tools/verificar_paridade.sh --release
```

O segundo comando deve bloquear a liberacao enquanto houver pendencias reais.
Validacao estrutural nao substitui testes funcionais, visuais ou em aparelhos.
Alteracoes comuns devem ser implementadas e verificadas nas duas plataformas.

## Arquivos mantidos fora do Git

- A versao preservada 1.0.14 e o projeto antigo da raiz.
- PDFs originais do acervo e resultados de conversao OCR em massa.
- SDKs, runtimes, caches, compilacoes, instaladores e arquivos de distribuicao.
- Chaves privadas, certificados, perfis, senhas e configuracoes locais de assinatura.
- Evidencias brutas de testes, videos e registros que podem identificar aparelhos.

Os recursos integrados e o catalogo usados pelo codigo permanecem versionados.
O conteudo das obras nao recebe autorizacao de redistribuicao por estar neste
repositorio. Mantenha-o privado e restrinja o acesso aos colaboradores autorizados.

Credenciais de teste devem ser configuradas em armazenamento seguro, nunca no
codigo, nos commits, nas issues ou nos relatorios. A assinatura de distribuicao
precisa ser configurada separadamente pelos responsaveis autorizados.

Os READMEs internos e instrucoes antigas podem descrever a primeira versao do
breviario. Para o estado atual, prevalecem o contrato e os relatorios datados em
`Paridade/`. Notas antigas de publicacao que continham credenciais foram excluidas.
