# Personal Agent Skills

Wlasne, wersjonowane skille dla OpenCode i innych agentow obslugujacych format
`SKILL.md`.

## Struktura

Kazdy skill znajduje sie w osobnym katalogu najwyzszego poziomu:

```text
.
├── cloudflare-system-design/
│   ├── SKILL.md
│   └── references/
├── docs/
│   └── creating-skills.md
└── scripts/
    └── install.sh
```

## Instalacja

Wszystkie skille globalnie dla OpenCode:

```bash
./scripts/install.sh --global
```

Tylko wybrane skille globalnie:

```bash
./scripts/install.sh --global cloudflare-system-design
```

Wszystkie skille w konkretnym projekcie:

```bash
./scripts/install.sh --project /sciezka/do/projektu
```

Skille sa kopiowane, a istniejace instalacje nie sa nadpisywane. Uzyj
`--force`, aby je zaktualizowac:

```bash
./scripts/install.sh --global --force cloudflare-system-design
```

Podczas rozwijania skilla mozna zamiast kopii utworzyc dowiazanie symboliczne:

```bash
./scripts/install.sh --global --link cloudflare-system-design
```

Po instalacji uruchom OpenCode ponownie. Konfiguracja i skille nie sa
przeladowywane w trakcie dzialajacej sesji.

## Dodawanie skilla

1. Utworz katalog, np. `database-design/`.
2. Dodaj w nim plik `SKILL.md`.
3. Ustaw `name` identyczne z nazwa katalogu.
4. Opisz w `description`, co skill robi oraz kiedy nalezy go uruchomic.
5. Zainstaluj go lokalnie i sprawdz na realistycznym zadaniu.

Pelne wskazowki i szablon znajduja sie w
[`docs/creating-skills.md`](docs/creating-skills.md).

## Publikacja

Repozytorium mozna umiescic na GitHubie jak zwykly projekt Git. Po utworzeniu
pustego repozytorium na GitHubie:

```bash
git remote add origin git@github.com:OWNER/REPOSITORY.git
git branch -M main
git push -u origin main
```

Uzytkownicy moga sklonowac repozytorium i skorzystac z instalatora. Format
katalogow jest tez zgodny z ekosystemem Agent Skills i pozwala instalowac
opublikowane skille narzedziami obslugujacymi repozytoria z `SKILL.md`.
