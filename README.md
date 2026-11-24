# NOPO Crew Beta

Aplicação independente para testar o novo fluxo **Projetos → ficha completa**, inspirada na organização do Rentman e com a identidade visual NOPO Crew Beta.

## Estrutura

- Código e histórico: este repositório GitHub.
- Alojamento: projeto Vercel `nopocrewbeta`, separado da app atual.
- Dados e autenticação: backend PostgreSQL exclusivo da Beta, provisionado através do Lovable Cloud. Não usa a base de dados da NOPO Crew atual.
- Frontend sem dependências; funções Vercel Node.js com autenticação por cookies HttpOnly.

## Funcionalidades

Projetos com referência única, filtros, pesquisa e CSV; ficha com Geral, Agenda, Equipa e funções, Agendamento, Transporte, Despesas, Documentos e Histórico. Sete fases com horários, necessidades por função, atribuições, cachets previstos e conflitos. Planeamento semanal e calendário mensal. Documentos por link, exportação CSV e impressão pelo navegador.

Os dados guardam na base de dados online. Cada conta tem um espaço de demonstração separado; nesta primeira fase, cada titular é administrador apenas do próprio espaço. Não há partilha de equipas entre contas nem os perfis operacionais da app atual. O diretório começa com exemplos fictícios e permite criar e editar técnicos internos e freelancers, marcar favoritos e inativar fichas sem apagar as atribuições históricas. As fichas não criam contas de login nem enviam convites.

## Configuração no Vercel

Variáveis de ambiente necessárias (não guardar valores no Git):

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

As migrações em `migrations/` pertencem **exclusivamente** ao backend da Beta. Não aplicar numa base de dados de produção existente.

## Testar

Criar conta da Beta, confirmar o email se solicitado e entrar. Os projetos de demonstração são criados automaticamente no primeiro acesso. Abrir um projeto com duplo clique ou o botão Abrir, editar e Guardar. Recarregar para confirmar a persistência. A sessão mantém-se neste navegador; Sair termina a sessão.

Testes automatizados: `npm test` (Node.js 22+). Não é necessário instalar dependências.

## Limites da Beta

Sem importação de dados da app atual, sem emails operacionais, sem validações de folgas/férias ou cachets, sem upload de anexos e sem perfis partilhados de administrador/gestor/financeiro. Os valores de despesas são previsões; exportações são CSV compatível com Excel. O objetivo é validar o novo fluxo de projetos antes de integrar as regras operacionais completas.

## Equipa, financeiro e datas

A área Equipa inclui pesquisa, filtros por setor/estado, favoritos, contactos e valores de referência opcionais. Valores em branco ficam por definir; zero é um valor definido. A área Financeiro reúne cachets fixos por fase e despesas manuais, com filtros por projeto/período, vistas por projeto e técnico, e CSV. Cachets não definidos estão assinalados. As despesas manuais não são repartidas por técnicos. Horas extra são referências, sem cálculo automático.

Datas apresentadas e preenchidas em DD/MM/AAAA; horários em DD/MM/AAAA HH:MM. Os dados internos conservam ISO para validação e ordenação.


## Beta 0.4
Projetos podem ser movidos para Apagados e recuperados, sem perda do histórico. Não entram no planeamento nem no financeiro enquanto apagados. A recuperação verifica conflitos.

A ficha da equipa organiza Dados, Administrativo, Tarifas, Documentos e Histórico. O campo horas incluídas define a referência para novas atribuições de freelancers. Na atribuição, o botão € permite definir o cachet, horas incluídas e valor extra, e reunir fases numa jornada. Cada jornada conta o intervalo contínuo entre primeira entrada e última saída, incluindo pausas e passagem da meia-noite, no fuso Europe/Lisbon. Não se aplicam descontos de refeição. As fases de dias distintos têm jornadas separadas por defeito; é possível reuni-las explicitamente. Tarifas antigas mantêm os valores fixos até serem configuradas. O financeiro e o CSV partilham os mesmos cálculos.

O acesso Sim/Não está ativo. Com Sim, email e ficha ativa, o administrador gera um código permanente reutilizável e prepara o email no programa de correio. O técnico entra com email e código; a sessão é mantida até revogação ou logout, guardada em cookie HttpOnly Secure SameSite=Lax. A base guarda apenas hashes dos códigos e sessões. Gerar novo código, mudar o email, desativar ou inativar a ficha revoga os acessos anteriores. O técnico consulta apenas as próprias fases futuras/em curso e os contactos profissionais do gestor e responsável, sem clientes, financeiro, documentos ou colegas. As APIs de escrita continuam a exigir autenticação de administrador.

O cookie do dispositivo é renovado em cada consulta, com a duração máxima de 400 dias permitida nos navegadores. Se o navegador limpar os cookies, o mesmo código permite voltar a entrar. Códigos e sessões anteriores não revogados passam também a permanentes.

## Importação NOPOcrew
Projetos, equipa e escalas são convertidos para o formato da Beta; os registos originais ficam preservados em sourceArchive no espaço privado. A aba Dados importados permite consultar disponibilidades, saldos, horas, confirmações, aprovações, notificações e auditoria. Os IDs e os estados apagados mantêm correspondência com a origem. PDFs permanecem ligados aos downloads autenticados da NOPOcrew; não foram tornados públicos. As contas, palavras-passe, sessões e chaves da app original não são copiadas. Nenhum acesso é concedido automaticamente aos técnicos. A cópia é pontual, sem sincronização automática. Dados reais nunca são guardados no repositório.
