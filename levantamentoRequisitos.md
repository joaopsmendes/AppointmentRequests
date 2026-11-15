# Levantamento de requisitos

Desafio: pesquisa de nutricionistas e pedidos de marcação (Rails + PostgreSQL + React).

## 1. Entidades

### Nutritionist
- id
- name
- license_number (único)
- photo_url
- created_at, updated_at

### Service
- id
- nutritionist_id
- description
- price_cents (inteiro, evita erros de arredondamento)
- duration_minutes
- location
- created_at, updated_at

### Guest
- id
- name
- email (único, insensível a maiúsculas)
- created_at, updated_at

### AppointmentRequest
- id
- nutritionist_id (redundante com o serviço, mas necessário para a exclusion constraint)
- service_id
- guest_id
- scheduled_at (data e hora de início)
- ends_at (= scheduled_at + duração do serviço, calculado ao criar)
- status (pending, accepted, rejected)
- answered_at
- created_at, updated_at

## 2. Constraints e índices

| O quê | Para quê |
|---|---|
| `guests.email` do tipo `citext`, com índice único | Identificar o guest pelo email, sem distinguir maiúsculas |
| Índice único parcial `appointment_requests (guest_id) WHERE status = 'pending'` | Um pedido pendente por guest |
| Exclusion constraint `(nutritionist_id WITH =, tstzrange(scheduled_at, ends_at) WITH &&) WHERE status = 'accepted'` (extensão `btree_gist`) | Sem consultas aceites sobrepostas |
| FK composta `(service_id, nutritionist_id) → services (id, nutritionist_id)` | O `nutritionist_id` do pedido é sempre o do serviço |
| `CHECK (ends_at > scheduled_at)` e `CHECK` dos estados válidos | Intervalo e estado válidos |
| `CHECK` de preço e duração positivos nos serviços | Serviços coerentes |
| Índice único em `nutritionists.license_number` | Sem nutricionistas duplicados |
| Índice `(nutritionist_id, status)` | Lista de pedidos do nutricionista |
| Colunas `nutritionists.name_search` e `services.description_search` (cópias sem acentos e em minúsculas, mantidas pelos modelos) | Pesquisa que ignora acentos, sem funções SQL |
| Índices trigram (`pg_trgm`) nessas colunas | Pesquisa com `ILIKE '%termo%'` e por semelhança (`<%`) |
| Chaves estrangeiras e `NOT NULL` | Integridade |

## 3. Use cases

### Guest
- **Pesquisar** por nome do nutricionista ou por descrição do serviço, sem distinguir maiúsculas nem acentos ("joao" encontra "João") e tolerando erros de escrita ("ana lma" encontra "Ana Lima", com a *word similarity* do `pg_trgm`). Os matches exatos aparecem primeiro. Devolve os nutricionistas com os seus serviços e preços, paginado e com `preload(:services)` para evitar N+1.
- **Criar AppointmentRequest** (nome, email, serviço, data e hora):
  - A data tem de ser futura.
  - O serviço tem de pertencer ao nutricionista escolhido (o nutricionista vem sempre do serviço).
  - Se o email já tiver um pedido pendente: 409 com mensagem amigável.
  - Se o guest tiver um pedido pendente cuja data já passou, esse pedido é rejeitado (regra 9) e o novo é criado.
  - Se o horário já estiver aceite para outro guest: 409 "horário indisponível".
  - Duplo clique: o frontend desativa o botão durante o pedido. A garantia final é o índice único.

### Nutritionist
- **Listar pedidos** por estado: pendentes (por omissão), aceites ou rejeitados (histórico). Os pendentes com a data já passada não aparecem.
- **Aceitar** ou **rejeitar** cada pedido (secção 4).
- O guest é sempre notificado por email, quer seja aceite, quer seja rejeitado.
- Sem autenticação: o nutricionista escolhe o seu perfil na página `/professionals`, a que se chega pelo link do cabeçalho.

### Endpoints
| Método | Rota | Descrição |
|---|---|---|
| GET | `/api/nutritionists?q=&page=&per_page=` | Pesquisa por nome ou serviço |
| POST | `/api/appointment_requests` | Criar pedido |
| GET | `/api/nutritionists/:id/appointment_requests?status=&page=&per_page=` | Pedidos do nutricionista, filtrados por estado (`pending` por omissão) |
| PATCH | `/api/appointment_requests/:id` | Responder ao pedido com `{ "status": "accepted" }` ou `{ "status": "rejected" }`. Só permite a transição a partir de `pending`. Ao aceitar, devolve os ids rejeitados automaticamente |

Códigos de erro: 400 (falta a chave raiz do body), 404 (não existe), 409 (conflito com o estado atual), 422 (dados inválidos).

## 4. Regras de negócio

1. Um pedido pendente **não reserva** o slot. É um pedido a uma pessoa que decide. Vários guests podem pedir a mesma hora, e só um pedido **aceite** ocupa o slot.
2. Um guest só pode ter **um pedido pendente** de cada vez, no total (por email).
3. **Aceitar um pedido** (`PATCH` com `status: accepted`, tudo numa só transação):
   1. Tranca a linha do nutricionista (lock pessimista, secção 6).
   2. Marca o pedido como `accepted` com UPDATE condicional (`WHERE status = 'pending'`). Se já tinha sido respondido, devolve 409.
   3. Se o intervalo `[scheduled_at, ends_at)` se sobrepõe a uma consulta já aceite do mesmo nutricionista (incluindo a mesma hora), a base de dados recusa. O backend devolve 409 com a mensagem "Cannot accept: it overlaps an already accepted appointment", e o frontend mostra-a.
   4. Se correu bem, rejeita automaticamente os pedidos pendentes que ficaram sem horário:
      - do mesmo guest, para a mesma data e hora (regra do enunciado; com a regra 2 dificilmente dispara);
      - de **outros guests** do mesmo nutricionista cujo intervalo se sobrepõe ao que acabou de ser aceite.
   5. Depois do commit, notifica por email cada guest respondido (o aceite e os rejeitados automaticamente) através do `NotificationService` (secção 5).
4. **Se a aceitação falhar** (sobreposição ou já respondido), é feito rollback: o pedido continua pendente, nada é rejeitado e nenhum email é enviado, porque a notificação só acontece depois do commit. O nutricionista pode rejeitá-lo manualmente.
5. **Rejeitar** (`PATCH` com `status: rejected`): UPDATE condicional (`WHERE status = 'pending'`) e, depois do commit, notifica o guest.
6. Ao aceitar, os pedidos pendentes de **outros** guests que ficam sobrepostos são rejeitados automaticamente (decisão minha, além do enunciado, que só pede isso para o mesmo guest). Deixá-los pendentes para um horário que já não existe não faz sentido, e obrigava o nutricionista a descobrir o conflito só ao tentar aceitar.
7. Consultas encostadas (09:00–09:45 e 09:45–10:30) **não** são sobreposição, porque o intervalo é aberto no fim (`[)`).
8. **O que o nutricionista vê ao aceitar:** o modal avisa que aceitar também rejeita os pendentes sobrepostos. Depois de aceitar, uma mensagem diz quantos foram rejeitados automaticamente ("1 overlapping request was automatically rejected"), a partir dos ids devolvidos pelo `accept`, e a lista é recarregada. Uma confirmação **antes** de aceitar, com os nomes e as horas dos pedidos que vão ser rejeitados, ficou como trabalho futuro (secção 8).
9. **Pedidos pendentes com a data já passada** (o nutricionista não respondeu a tempo):
   - Quando o guest faz um pedido novo, os seus pendentes passados são rejeitados na mesma transação, **sem email** (o guest está nesse momento a fazer outro pedido). Sem isto, a regra 2 deixava-o bloqueado para sempre.
   - Não aparecem na lista de pendentes do nutricionista.
   - Aceitá-los dá 422, porque marcaria uma consulta no passado. Rejeitá-los continua permitido.
   - O índice parcial da regra 2 não pode ignorar sozinho os pedidos passados, porque o `WHERE` de um índice não aceita `now()`. Por isso, o estado do pedido tem de mudar.

## 5. Notificações

O enunciado pede um email ao guest quando o pedido é respondido. Versão simples, atrás de um serviço próprio:

1. Aceitar ou rejeitar corre numa transação (secção 4).
2. **Depois do commit**, para cada guest respondido, chama-se `NotificationService.notify(request)`, que faz `GuestMailer.answered(request).deliver_later` (ActiveJob).
3. O envio nunca acontece dentro da transação: um email enviado não se desfaz com um rollback, e uma chamada a um serviço externo deixava a transação aberta, com os locks presos.
4. Com rollback não há notificação, porque o serviço só é chamado depois do commit.
5. As horas nos emails estão na hora de Lisboa (`config.time_zone = "Lisbon"`). Na base de dados continuam em UTC.

**Porquê um `NotificationService`:** isola a forma de enviar. Trocar o `deliver_later` por uma outbox (secção 8) passa a ser uma alteração num só sítio.

**Limites conhecidos**
- Se o processo morrer entre o commit e o envio para a fila, o email perde-se (dual write).
- O adaptador por omissão (`:async`) não persiste os jobs nem repete falhas. É aceitável neste desafio, porque o email é informativo.

## 6. Concorrência

| Caso | Risco | Garantia |
|---|---|---|
| Criar vs criar: o mesmo guest envia dois pedidos ao mesmo tempo | Dois pendentes para o mesmo guest | Índice único parcial → 409 |
| Aceitar vs aceitar: dois pedidos sobrepostos aceites ao mesmo tempo | Marcação dupla | Exclusion constraint → 409 (a garantia final), e o lock no nutricionista põe os aceites em fila |
| Aceitar/rejeitar o mesmo pedido duas vezes (duplo clique, dois separadores) | Resposta dupla | UPDATE condicional (0 linhas → 409) |
| **Criar vs aceitar:** um pedido novo criado enquanto um sobreposto é aceite | O pedido novo passa a verificação do horário (o aceite ainda não fez commit) e não é visto pela rejeição automática: fica pendente num horário ocupado | **Lock pessimista** na linha do nutricionista (`SELECT ... FOR UPDATE`) no Create e no Answer: quem chega em segundo espera e vê o que o primeiro gravou |

- O lock só põe em fila os pedidos **do mesmo nutricionista**. Os de nutricionistas diferentes continuam em paralelo.
- Os dois use cases trancam pela mesma ordem (primeiro o nutricionista, depois os pedidos), por isso não há deadlocks entre eles. O retry em caso de deadlock (até 3 tentativas) fica como rede de segurança.
- **Alternativas consideradas:**
  - `SERIALIZABLE` + retry: o PostgreSQL deteta o conflito sozinho, mas obriga a fazer retry nos dois use cases;
  - lock otimista (`lock_version`): também obriga a retry;
  - advisory lock: é a mesma ideia, mas menos óbvia para quem lê o código.
- Mesmo que o frontend bloqueie estes casos, o backend bloqueia-os também: o frontend pode ser contornado.
- Cada caso tem um teste com threads reais (`concurrency_test.rb`).

## 7. Logs

O Rails já regista cada pedido (parâmetros, queries, código HTTP) e o backtrace dos erros 500. Acrescentei logs só para as decisões que o código toma em silêncio, com o formato `[UseCase] evento chave=valor` e só ids, sem dados pessoais:
- o retry por deadlock (`warn`: com o lock, não devia acontecer);
- os pedidos rejeitados automaticamente ao aceitar;
- os aceites recusados pela exclusion constraint;
- os pedidos simultâneos recusados pelo índice único;
- os pendentes expirados rejeitados no Create.

## 8. Trabalho Futuro

- **Confirmação antes de aceitar** com os pedidos que vão ser rejeitados (nome e hora): um `GET /api/appointment_requests/:id/conflicts` chamado quando o modal abre, ou a contagem de pendentes sobrepostos em cada pedido da lista, numa só query (sem N+1). A definição de "conflito" teria de ser a mesma usada pelo `Answer`.
- **Horários ocupados no modal de marcação:** um `GET /api/nutritionists/:id/busy_slots?date=` com os intervalos aceites desse dia (só as horas, sem dados dos guests). O modal mostraria "Already booked on this day: 10:00–11:00" e avisaria se a hora escolhida, mais a duração do serviço, se sobrepusesse. O `datetime-local` não deixa desativar horas, por isso seria um aviso e não horas bloqueadas. O Create continua a ser a garantia (409).
- **Filtro por localização** na pesquisa (o campo "Location" do mockup).
- **Job agendado para os pendentes expirados:** rejeitá-los no momento em que a data passa, com um email "o nutricionista não respondeu a tempo".
- **Idempotency-Key no POST:** o índice único já impede pedidos duplicados.
- **Motor de pesquisa externo** (Elasticsearch, Meilisearch): o `pg_trgm` com as colunas normalizadas chega a esta escala, sem um serviço extra para correr e sincronizar.
- **Autenticação e calendário de disponibilidade:** fora do enunciado.
- **Outbox para os emails:** `deliver_later` chega aqui. Em produção, tabela outbox mais um worker com retries, porque um email não é atómico com o commit.
- **Auditoria das decisões:** passar o aceitar/rejeitar a `POST /api/appointment_requests/:id/decisions`, que cria um registo imutável por decisão (pedido, estado anterior e novo, data e, havendo autenticação, quem decidiu). O PATCH atualiza o estado no sítio e perde o histórico. O que dá auditoria é o registo, não o verbo POST.
- **Observabilidade:** error tracking (Sentry, por exemplo) e logs estruturados em JSON (`lograge`).
