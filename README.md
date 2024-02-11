# DockerSQL
Um projeto pronto para rodar o **SQL Server** via Docker.

Para funcionar corretamente, recomendo utilizar o comando:
- docker compose up (pode adicionar o parâmetro -d para não seguir os logs, ou iniciar pelo Docker Desktop)

Com o compose, será criado 3 pastas, **Data**, **Backup** e **Log**, onde:
- Data manterá os arquivos mdf, ldf e quaisquer arquivo dos bancos de dados.
- Backup é onde você poderá copiar arquivos .bak para restaurar (via query ou GUI)
- Log é onde os arquivos de log do SQL serão salvos.

Caso inicie o projeto via docker run, precisará informar os volumes citados além de expor as portas e as variáveis do ambiente, futuramente postarei a linha de comando.
