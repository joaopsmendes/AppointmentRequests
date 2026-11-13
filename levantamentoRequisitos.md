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
- **Pesquisar** por nome do nutricionista ou por descrição do serviço. Devolve os nutricionistas com os seus serviços e preços, paginado e com `includes(:services)` para evitar N+1.
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
| GET | `/api/nutritionists/:id/appointment_requests?status=pending` | Pedidos do nutricionista, cada um com a contagem de pendentes sobrepostos |
| PATCH | `/api/appointment_requests/:id` | Responder ao pedido com `{ "status": "accepted" }` ou `{ "status": "rejected" }`. Só permite a transição a partir de `pending`. Ao aceitar, devolve os ids rejeitados automaticamente |

## 4. Regras de negócio

1. Um pedido pendente **não reserva** o slot. É um pedido a uma pessoa que decide. Vários guests podem pedir a mesma hora, e só um pedido **aceite** ocupa o slot.
2. Um guest só pode ter **um pedido pendente** de cada vez, no total (por email).
3. **Aceitar um pedido** (`PATCH` com `status: accepted`, tudo numa só transação):
   1. Marca-o como `accepted` com UPDATE condicional (`WHERE status = 'pending'`). Se já tinha sido respondido, devolve 409.
   2. Se o intervalo `[scheduled_at, ends_at)` se sobrepõe a uma consulta já aceite do mesmo nutricionista (incluindo a mesma hora), a base de dados recusa. O backend devolve 409 com a mensagem "Não é possível aceitar: sobrepõe-se a uma consulta já aceite", e o frontend mostra-a.
   3. Se correu bem, rejeita automaticamente os pedidos pendentes que ficaram sem horário:
      - do mesmo guest, para a mesma data e hora (regra do enunciado; com a regra 2 dificilmente dispara);
      - de **outros guests** do mesmo nutricionista cujo intervalo se sobrepõe ao que acabou de ser aceite.
   4. Depois do commit, notifica por email cada guest respondido (o aceite e os rejeitados automaticamente) através do `NotificationService` (secção 5).
4. **Se a aceitação falhar** (sobreposição ou já respondido), é feito rollback: o pedido continua pendente, nada é rejeitado e nenhum email é enviado, porque a notificação só acontece depois do commit. O nutricionista pode rejeitá-lo manualmente.
5. **Rejeitar** (`PATCH` com `status: rejected`): UPDATE condicional (`WHERE status = 'pending'`) e, depois do commit, notifica o guest.
6. Ao aceitar, os pedidos pendentes de **outros** guests que ficam sobrepostos são rejeitados automaticamente (decisão minha, além do enunciado, que só pede isso para o mesmo guest). Deixá-los pendentes para um horário que já não existe não faz sentido, e obrigava o nutricionista a descobrir o conflito só ao tentar aceitar.
7. Consultas encostadas (09:00–09:45 e 09:45–10:30) **não** são sobreposição, porque o intervalo é aberto no fim (`[)`).
8. **Aviso na UI antes de aceitar:** se o pedido tem outros pendentes sobrepostos, o frontend pede confirmação ("Ao aceitar, vão ser rejeitados automaticamente N pedidos: nome, hora…"). A lista já traz essa contagem, calculada numa só query (sem N+1). O aviso é informativo e pode estar desatualizado, por isso o backend é a autoridade e a resposta do `accept` devolve os ids rejeitados para a UI se atualizar.

## 5. Notificações

O enunciado pede um email ao guest quando o pedido é respondido. Versão simples, atrás de um serviço próprio:

1. Aceitar ou rejeitar corre numa transação (secção 4).
2. **Depois do commit**, para cada guest respondido, chama-se `NotificationService.notify(request)`, que faz `GuestMailer.answered(request).deliver_later` (ActiveJob).
3. O envio nunca acontece dentro da transação: um email enviado não se desfaz com um rollback, e uma chamada a um serviço externo deixava a transação aberta, com os locks presos.
4. Com rollback não há notificação, porque o serviço só é chamado depois do commit.

**Porquê um `NotificationService`:** isola a forma de enviar. Trocar o `deliver_later` por uma outbox (secção 7) passa a ser uma alteração num só sítio.

**Limites conhecidos**
- Se o processo morrer entre o commit e o envio para a fila, o email perde-se (dual write).
- O adaptador por omissão (`:async`) não persiste os jobs nem repete falhas. É aceitável neste desafio, porque o email é informativo.

## 6. Concorrência

| Momento | Regra | Garantia |
|---|---|---|
| Criar pedido | Guest só tem 1 pendente | Índice único parcial → 409 |
| Criar pedido | Horário já aceite por outro guest | Verificação de leitura (feedback) |
| Aceitar | Sobreposição com uma consulta aceite | Exclusion constraint → 409 |
| Aceitar/rejeitar | Já foi respondido (duplo clique, dois separadores) | UPDATE condicional (0 linhas → 409) |
| Aceitar | Pendentes sobrepostos de outros guests | Rejeitados na mesma transação do aceite |

Dois guests a pedirem a mesma hora em simultâneo não geram conflito, porque não há recurso exclusivo a proteger: ficam os dois pendentes e o nutricionista decide. O único recurso exclusivo é a consulta aceite, e é aí que está a garantia na base de dados.

## 7. Trabalho Futuro

- **Idempotency-Key no POST:** o índice único já impede pedidos duplicados.
- **Motor de pesquisa externo:** `pg_trgm` com `unaccent` chega a esta escala.
- **Autenticação e calendário de disponibilidade:** fora do enunciado.
- **Outbox para os emails:** `deliver_later` chega aqui. Em produção, tabela outbox mais um worker com retries, porque um email não é atómico com o commit.
- **Auditoria das decisões:** passar o aceitar/rejeitar a `POST /api/appointment_requests/:id/decisions`, que cria um registo imutável por decisão (pedido, estado anterior e novo, data e, havendo autenticação, quem decidiu). O PATCH atualiza o estado no sítio e perde o histórico. O que dá auditoria é o registo, não o verbo POST.