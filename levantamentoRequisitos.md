# Levantamento de requisitos

Desafio: pesquisa de nutricionistas e pedidos de marcação (Rails + PostgreSQL + React).

## 1. Entidades

### Nutritionist
- id
- name
- license_number
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
| `guests.email` único e insensível a maiúsculas (`citext` ou índice em `lower(email)`) | Identificar o guest pelo email |
| Índice único parcial `appointment_requests (guest_id) WHERE status = 'pending'` | Um pedido pendente por guest |
| Exclusion constraint `(nutritionist_id WITH =, tstzrange(scheduled_at, ends_at) WITH &&) WHERE status = 'accepted'` (extensão `btree_gist`) | Sem consultas aceites sobrepostas |
| `CHECK (ends_at > scheduled_at)` | Intervalo válido |
| Índice `(nutritionist_id, status)` | Lista de pedidos do nutricionista |
| Índices trigram (`pg_trgm` + `unaccent`) em `nutritionists.name` e `services.description` | Pesquisa por nome e por serviço |
| Chaves estrangeiras e `NOT NULL` | Integridade |

## 3. Use cases

### Guest
- **Pesquisar** por nome do nutricionista ou por descrição do serviço. Devolve os nutricionistas com os seus serviços e preços, paginado e com `includes(:services)` para evitar N+1. (getbyfilter?nutricionistaName=.../service=....)
- **Criar AppointmentRequest** (nome, email, serviço, data e hora):
  - A data tem de ser futura.
  - O serviço tem de pertencer ao nutricionista escolhido.
  - Se o email já tiver um pedido pendente: 409 com mensagem amigável.
  - Se o horário já estiver aceite para outro guest: 409 "horário indisponível" (verificação de leitura, só para dar feedback rápido).
  - Duplo clique: o frontend desativa o botão durante o pedido. A garantia final é o índice único.

### Nutritionist
- **Listar pedidos** (por omissão, `pending`).
- **Aceitar** ou **rejeitar** cada pedido (secção 4).
- O guest é sempre notificado por email, quer seja aceite, quer seja rejeitado.

### Endpoints (proposta)
| Método | Rota | Descrição |
|---|---|---|
| GET | `/api/nutritionists?q=&page=` | Pesquisa por nome ou serviço |
| POST | `/api/appointment_requests` | Criar pedido |
| GET | `/api/nutritionists/:id/appointment_requests?status=pending` | Pedidos do nutricionista |
| POST | `/api/appointment_requests/:id/accept` | Aceitar |
| POST | `/api/appointment_requests/:id/reject` | Rejeitar |

## 4. Regras de negócio

1. Um pedido pendente **não reserva** o slot. É um pedido a uma pessoa que decide. Vários guests podem pedir a mesma hora, e só um pedido **aceite** ocupa o slot.
2. Um guest só pode ter **um pedido pendente** de cada vez, no total (por email).
3. **Aceitar um pedido** (tudo numa só transação):
   1. Marca-o como `accepted` com UPDATE condicional (`WHERE status = 'pending'`). Se já tinha sido respondido, devolve 409.
   2. Se o intervalo `[scheduled_at, ends_at)` se sobrepõe a uma consulta já aceite do mesmo nutricionista (incluindo a mesma hora), a base de dados recusa. O backend devolve 409 com a mensagem "Não é possível aceitar: sobrepõe-se a uma consulta já aceite", e o frontend mostra-a.
   3. Se correu bem, rejeita automaticamente os pedidos pendentes que ficaram sem horário:
      - do mesmo guest, para a mesma data e hora (regra do enunciado; com a regra 2 dificilmente dispara);
      - de **outros guests** do mesmo nutricionista cujo intervalo se sobrepõe ao que acabou de ser aceite.
   4. Depois do commit, envia o email a todos os guests respondidos: o aceite e os rejeitados automaticamente (`deliver_later`).
4. **Se a aceitação falhar** (sobreposição ou já respondido), é feito rollback: o pedido continua pendente, nada é rejeitado e nenhum email é enviado. O nutricionista pode rejeitá-lo manualmente.
5. **Rejeitar:** UPDATE condicional (`WHERE status = 'pending'`) e email ao guest depois do commit.
6. Ao aceitar, os pedidos pendentes de **outros** guests que ficam sobrepostos são rejeitados automaticamente (decisão minha, além do enunciado, que só pede isso para o mesmo guest). Deixá-los pendentes para um horário que já não existe não faz sentido, e obrigava o nutricionista a descobrir o conflito só ao tentar aceitar.
7. Consultas encostadas (09:00–09:45 e 09:45–10:30) **não** são sobreposição, porque o intervalo é aberto no fim (`[)`).

## 5. Concorrência

| Momento | Regra | Garantia |
|---|---|---|
| Criar pedido | Guest só tem 1 pendente | Índice único parcial → 409 |
| Criar pedido | Horário já aceite por outro guest | Verificação de leitura (feedback) |
| Aceitar | Sobreposição com uma consulta aceite | Exclusion constraint → 409 |
| Aceitar/rejeitar | Já foi respondido (duplo clique, dois separadores) | UPDATE condicional (0 linhas → 409) |
| Aceitar | Pendentes sobrepostos de outros guests | Rejeitados na mesma transação do aceite |

Dois guests a pedirem a mesma hora em simultâneo não geram conflito, porque não há recurso exclusivo a proteger: ficam os dois pendentes e o nutricionista decide. O único recurso exclusivo é a consulta aceite, e é aí que está a garantia na base de dados.

## 6. Dúvidas levantadas e decisões

| Dúvida | Decisão | Porquê |
|---|---|---|
| Os slots pendentes aparecem como ocupados para outros guests? | Não. Só os aceites ocupam o slot | Pendente é um pedido a uma pessoa que decide. Bloquear exigia expiração (mais scope) |
| Em concorrência, deixo o sistema aceitar e o nutricionista decide, ou indico logo ao guest que o slot não está disponível? | Pendentes: aceita-se e o nutricionista decide. Se já existe um aceite: aviso ao criar (feedback) e garantia ao aceitar (constraint) | A garantia só é precisa na escrita exclusiva (aceitar) |
| Preciso da tabela Guest? | Sim | O guest é identificado pelo email e a regra do pendente fica limpa |
| POST ou PUT/PATCH para aceitar e rejeitar? | `POST .../accept` e `POST .../reject` | A intenção fica explícita e controlo as transições |
| O POST de criar tem de ser idempotente? | Não precisa de Idempotency-Key | O índice único já impede duplicados; o botão desativa-se durante o pedido |
| "Um pendente por horário" ou "um pendente por email"? | Um por email, no total | Regra do enunciado; a rejeição automática fica como salvaguarda |
| Guardo a duração? | Sim, com `ends_at` no pedido | A exclusion constraint precisa do intervalo; se o serviço mudar, as marcações antigas não mudam. Se o tempo apertar, simplifico para um slot |
| Ao aceitar, rejeito os pedidos pendentes de outros guests para esse slot? | Sim, os que se sobrepõem, na mesma transação, com email a cada um | Evita pedidos pendentes para um horário que já não existe e conflitos só descobertos ao aceitar. A constraint continua a ser a garantia em caso de corrida |

## 7. O que cortei (para o README)

- **Idempotency-Key no POST:** o índice único já impede pedidos duplicados.
- **Motor de pesquisa externo:** `pg_trgm` com `unaccent` chega a esta escala.
- **Autenticação e calendário de disponibilidade:** fora do enunciado.
- **Outbox para os emails:** `deliver_later` chega aqui. Em produção, tabela outbox mais um worker com retries, porque um email não é atómico com o commit.