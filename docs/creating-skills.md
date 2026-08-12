# Tworzenie skilli

## Minimalny format

Utworz `<nazwa>/SKILL.md`:

```markdown
---
name: nazwa-skilla
description: Opisuje, co skill robi i kiedy nalezy go uzyc. Use when uzytkownik prosi o konkretne zadanie lub wymienia powiazane technologie.
---

# Nazwa skilla

## Workflow

1. Zbierz wymagania i ograniczenia.
2. Wykonaj zadanie wedlug ponizszych zasad.
3. Zweryfikuj wynik.

## Rules

- Dodaj konkretne instrukcje dziedzinowe.
- Zdefiniuj oczekiwany format odpowiedzi.
- Wskaz sytuacje, w ktorych agent powinien zadac pytanie.
```

`name` musi:

- odpowiadac nazwie katalogu,
- zawierac male litery, cyfry i myslniki,
- miec maksymalnie 64 znaki.

`description` odpowiada za wykrywanie skilla. Powinno zawierac slowa, ktorych
uzytkownik faktycznie uzyje, i laczyc dwie informacje:

- co skill potrafi,
- kiedy powinien zostac uzyty.

## Zasady pisania

- Pisz instrukcje operacyjne, a nie ogolny artykul o danej dziedzinie.
- Dodaj kolejnosc dzialan, reguly decyzyjne i kryteria weryfikacji.
- Nie powtarzaj wiedzy, ktora model zwykle posiada, jesli nie zmienia ona jego
  decyzji.
- Okresl format rezultatu, gdy spojnosc odpowiedzi jest istotna.
- Dodaj przyklady tylko wtedy, gdy usuwaja niejednoznacznosc.
- Nie lacz kilku niezaleznych dziedzin w jednym skillu.
- Dla waskiego skilla zacznij opis od `Use ONLY when...`, aby ograniczyc
  przypadkowe uruchamianie.

## Testowanie

Dobry zestaw recznych testow zawiera:

1. Polecenie, ktore bezsprzecznie powinno uruchomic skill.
2. Polecenie podobne, ale znajdujace sie poza jego zakresem.
3. Niepelne wymagania, przy ktorych agent powinien zadac pytania.
4. Zadanie wymagajace zastosowania najwazniejszej reguly skilla.

Po kazdej zmianie zainstaluj skill z `--force` albo korzystaj z `--link`, a
nastepnie uruchom nowa sesje OpenCode.

## Kolejne dobre kandydatury

- `database-design`
- `code-review`
- `testing-strategy`
- `observability`
- `system-design`
- `technical-writing`

Kazdy z nich powinien miec waski zakres i wlasne kryteria jakosci.
