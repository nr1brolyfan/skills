# System design: rejestracja użytkownika z emailem weryfikacyjnym

## Założenia

Po rejestracji konto otrzymuje status `pending_verification`. Użytkownik powinien szybko dostać odpowiedź z API, a chwilowa awaria dostawcy emaila nie powinna wymuszać ponownej rejestracji.

## I. Synchroniczna wysyłka emaila

Backend zapisuje użytkownika, wysyła email i dopiero wtedy odpowiada aplikacji.

```mermaid
sequenceDiagram
    actor U as Użytkownik
    participant A as Mobile App
    participant B as Backend Worker
    participant D as Database
    participant E as Email Provider

    U->>A: Zarejestruj
    A->>B: POST /register
    B->>D: INSERT user
    D-->>B: OK
    B->>E: Wyślij email
    Note over A,E: Użytkownik nadal widzi loading
    E-->>B: OK lub błąd/timeout
    B-->>A: Odpowiedź
```

**Problem:** dostawca emaila może odpowiadać przez 10 sekund, zwrócić błąd albo wcale nie odpowiedzieć. Zewnętrzny efekt uboczny, który nie jest potrzebny do odpowiedzi HTTP, powinien być background jobem.

Nie warto również wysyłać emaila wewnątrz transakcji bazodanowej. Transakcja nie obejmuje dostawcy emaila i nie potrafi cofnąć już wysłanej wiadomości. Długie wywołanie sieciowe niepotrzebnie przedłuża też transakcję.

## II. Asynchroniczna wysyłka przez kolejkę

Backend zapisuje użytkownika i publikuje job do Cloudflare Queue. Osobny consumer Worker wysyła email.

```mermaid
flowchart LR
    A[Mobile App] --> B[Backend Worker]
    B -->|1. INSERT user| D[(Auth tables)]
    B -->|2. Publish job| Q[[Cloudflare Queue]]
    Q --> C[Consumer Worker]
    C --> E[Email Provider]

    style D fill:#dbeafe,stroke:#2563eb
    style Q fill:#fef3c7,stroke:#d97706
```

**Problem: dual write.** Backend wykonuje dwa niezależne zapisy. Zapis użytkownika może się udać, a publikacja do kolejki może zawieść. Konto istnieje, ale job odpowiedzialny za email przepadł.

Rozdwojenie przepływu na dwa niezależne systemy powinno od razu skłaniać do sprawdzenia scenariuszy częściowego sukcesu.

## III. Transactional outbox

Backend zapisuje użytkownika i zdarzenie `SendVerificationEmail` do tabeli `outbox` w jednej transakcji bazodanowej. Oba rekordy powstają albo nie powstaje żaden.

```mermaid
flowchart LR
    A[Mobile App] --> B[Backend Worker]

    subgraph TX[Jedna transakcja DB]
        U[(users)]
        O[(outbox)]
    end

    B -->|INSERT user + event| TX
    TX -->|Commit| R[Odpowiedź: rejestracja przyjęta]
    R --> A

    S[Scheduled Worker<br/>Outbox Relay] -->|Czyta pending events| O
    S -->|Publikuje event| Q[[Cloudflare Queue]]
    Q --> C[Consumer Worker]
    C --> E[Email Provider]

    style TX fill:#dcfce7,stroke:#16a34a
    style Q fill:#fef3c7,stroke:#d97706
```

Przykładowy rekord outbox:

```text
event_id:   018f...                 # UUID/ULID utworzone przed transakcją
event_type: SendVerificationEmail
payload:    { userId, email, verificationToken }
status:     pending
created_at: ...
published_at: null
```

`event_id` jest stałym identyfikatorem zdarzenia. Ten sam identyfikator trafia później do wiadomości w kolejce i służy jako idempotency key.

### Implementacja na Cloudflare

W D1 można użyć `DB.batch([insertUser, insertOutbox])`. D1 wykonuje taki batch jako transakcję i cofa całą sekwencję, jeśli jedna instrukcja zawiedzie.

`batch()` wystarcza, gdy instrukcje można przygotować z góry, na przykład po wygenerowaniu `user_id` oraz `event_id` w aplikacji. D1 nie udostępnia jednak typowej, interaktywnej transakcji, w której aplikacja wykonuje zapytanie, analizuje wynik i na tej podstawie wykonuje kolejne zapytania w tej samej transakcji. Przy wielu takich przypadkach lepszym wyborem może być Postgres albo SQLite-backed Durable Object, jeśli dane można naturalnie podzielić między obiekty.

Outbox Relay może być Scheduled Worker uruchamiany przez Cron Trigger. Dobrym punktem startowym jest **co minutę**. Interwał można zwiększyć do 2-5 minut, jeśli opóźnienie emaila jest akceptowalne, albo zastosować częstszy/inny mechanizm, jeśli minuta to zbyt długo.

Relay wykonuje następujące kroki:

1. Pobiera niewielką partię rekordów `pending` z `outbox`.
2. Publikuje każdy rekord do Cloudflare Queue wraz z jego `event_id`.
3. Po udanej publikacji ustawia `published_at`.

Publikacja do kolejki i aktualizacja `published_at` nadal nie są jedną transakcją. Jeśli relay opublikuje wiadomość i padnie przed aktualizacją rekordu, opublikuje ją ponownie. To jest bezpieczne dopiero wtedy, gdy cały dalszy przepływ toleruje duplikaty.

## IV. At-least-once delivery i retry

Cloudflare Queues zapewnia dostarczenie **at least once**. Consumer potwierdza wiadomość dopiero po udanej obsłudze.

```mermaid
sequenceDiagram
    participant Q as Cloudflare Queue
    participant W as Consumer Worker
    participant E as Email Provider
    participant D as Dead-letter Queue

    Q->>W: Dostarcz job
    W->>E: Wyślij email
    alt Wysyłka udana
        E-->>W: Success
        W-->>Q: msg.ack()
    else Błąd tymczasowy
        E-->>W: Timeout / 429 / 5xx
        W-->>Q: msg.retry(delaySeconds)
        Q->>W: Ponowne dostarczenie
    else Przekroczono max_retries
        Q->>D: Przenieś wiadomość do DLQ
    end
```

W Cloudflare consumer może:

- wywołać `msg.ack()` po sukcesie,
- wywołać `msg.retry({ delaySeconds })` po błędzie tymczasowym,
- pozwolić, aby nieobsłużony błąd spowodował retry,
- po przekroczeniu `max_retries` skierować wiadomość do skonfigurowanej DLQ.

Retry powinien mieć opóźnienie, najlepiej exponential backoff. Błędy trwałe, na przykład niepoprawny adres email, nie powinny być ponawiane bez końca.

**Problem:** dostawca może przyjąć email, po czym Worker straci połączenie, zostanie zatrzymany albo nie zdąży wykonać `ack()`. Kolejka dostarczy job ponownie i email może zostać wysłany drugi raz.

## V. Idempotentne przetwarzanie

Nie zakładamy, że job zostanie wykonany dokładnie raz. Zakładamy, że może zostać dostarczony wiele razy, a ponowne przetworzenie ma nie powodować nowych skutków.

```mermaid
flowchart TD
    Q[[Cloudflare Queue]] --> W[Consumer Worker]
    W -->|event_id jako idempotency key| E[Email Provider]
    E -->|Pierwsze żądanie| S[Wyślij email]
    E -->|Powtórzone event_id| X[Zwróć poprzedni wynik<br/>bez ponownej wysyłki]
    S --> ACK[msg.ack]
    X --> ACK

    style S fill:#dcfce7,stroke:#16a34a
    style X fill:#e0e7ff,stroke:#4f46e5
```

### Gdzie przechowywać `job_id`

Źródłem identyfikatora jest `outbox.event_id`. Nie generujemy nowego ID przy każdym retry ani przy ponownej publikacji. Ten sam `event_id` przechodzi przez cały system:

```text
outbox.event_id -> queue message.event_id -> provider idempotency key
```

Dla efektów wykonywanych we własnej bazie można prowadzić tabelę:

```sql
CREATE TABLE processed_jobs (
    event_id TEXT PRIMARY KEY,
    processed_at TEXT NOT NULL
);
```

Unikalny klucz chroni przed równoległym przetworzeniem tego samego zdarzenia. Zapis do `processed_jobs` powinien być częścią tej samej transakcji co lokalny efekt danego joba.

### Idempotency key u dostawcy emaila

Jeśli API dostawcy obsługuje idempotency keys, Worker przekazuje `event_id` w wymaganym nagłówku lub polu żądania. Dostawca trwale kojarzy klucz z pierwszym żądaniem i przy powtórzeniu nie wysyła kolejnego emaila.

Sama lokalna tabela `processed_jobs` nie daje pełnej gwarancji dla zewnętrznego emaila:

- zapis ID przed wysyłką może sprawić, że po awarii email nigdy nie zostanie wysłany,
- zapis ID po wysyłce pozostawia możliwość duplikatu, jeśli Worker padnie pomiędzy tymi operacjami.

Jeśli dostawca nie obsługuje idempotency key, nie da się atomowo połączyć jego API z własną bazą. W praktyce akceptujemy rzadki duplikat, używamy w obu wiadomościach tego samego tokenu weryfikacyjnego i dbamy, aby endpoint weryfikacji także był idempotentny.

## Docelowa architektura

```mermaid
flowchart LR
    A[Mobile App] -->|POST /register| B[Backend Worker]

    subgraph D1[D1: atomowy batch]
        U[(users<br/>pending_verification)]
        O[(outbox<br/>pending event)]
    end

    B -->|INSERT + INSERT| D1
    B -->|Szybka odpowiedź| A

    CRON[Cron Trigger<br/>np. co 1 min] --> R[Scheduled Worker<br/>Outbox Relay]
    R -->|SELECT pending| O
    R -->|Publish event_id| Q[[Cloudflare Queue]]
    R -->|Mark published| O

    Q --> C[Consumer Worker]
    C -->|event_id = idempotency key| E[Email Provider]
    C -->|Success: ack| Q
    C -->|Temporary failure: retry + backoff| Q
    Q -->|max_retries| DLQ[[Dead-letter Queue]]

    style D1 fill:#dcfce7,stroke:#16a34a
    style Q fill:#fef3c7,stroke:#d97706
    style DLQ fill:#fee2e2,stroke:#dc2626
```

Ostateczna gwarancja brzmi: **atomowy zapis użytkownika i zamiaru wysłania emaila, at-least-once delivery oraz idempotentne przetwarzanie**. Nie jest to prawdziwe exactly-once delivery, ale system nie gubi jobów i bezpiecznie odzyskuje się po typowych awariach.

Warto dodatkowo zapewnić użytkownikowi opcję „Wyślij email ponownie” oraz monitorować wielkość backlogu, liczbę retry, wiek najstarszego rekordu outbox i wiadomości trafiające do DLQ.
