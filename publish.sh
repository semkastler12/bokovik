#!/usr/bin/env bash
# Публикация статьи на GitHub Pages.
# Токен читается из файла (по умолчанию ~/.github-token), в вывод никогда не печатается.
#   ./publish.sh [файл-с-токеном] [имя-репозитория]
set -euo pipefail

TOKEN_FILE="${1:-$HOME/.github-token}"
REPO="${2:-bokovik}"
OWNER="semkastler12"
SITE="/home/inrd/trading"
API="https://api.github.com"

[ -f "$TOKEN_FILE" ] || { echo "Нет файла с токеном: $TOKEN_FILE" >&2; exit 1; }
TOKEN="$(tr -d ' \t\r\n' < "$TOKEN_FILE")"
[ -n "$TOKEN" ] || { echo "Файл с токеном пустой" >&2; exit 1; }

api() { curl -s --max-time 30 -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github+json" "$@"; }

echo "== 1. Проверка токена =="
api -I "$API/user" >/dev/null 2>&1 || true
curl -sI --max-time 25 -H "Authorization: token $TOKEN" "$API/user" \
  | tr -d '\r' | awk -F': ' 'tolower($1)=="x-oauth-scopes"{print "scopes: "$2}'
api "$API/user" -o /tmp/pub_user.json
python3 - <<'PY'
import json
d = json.load(open('/tmp/pub_user.json'))
if 'login' not in d:
    raise SystemExit('Токен не работает: ' + str(d.get('message')))
print('аккаунт:', d['login'])
PY

echo
echo "== 2. Репозиторий $OWNER/$REPO =="
code=$(api -o /tmp/pub_create.json -w '%{http_code}' -X POST "$API/user/repos" \
  -d "{\"name\":\"$REPO\",\"private\":false,\"has_issues\":false,\"has_wiki\":false,\"has_projects\":false,
       \"description\":\"Боковик: почему в него не надо лезть — разбор, психология, объём позиции и 11 реальных сделок\"}")
case "$code" in
  201) echo "создан" ;;
  422) echo "уже существует — продолжаю" ;;
  *)   echo "не удалось создать (HTTP $code): $(python3 -c "import json;print(json.load(open('/tmp/pub_create.json')).get('message'))" 2>/dev/null)"; exit 1 ;;
esac

echo
echo "== 3. Сборка сайта =="
cd "$SITE"
cp -f bokovik-i-obem-pozicii.html index.html
touch .nojekyll
[ -d .git ] || { git init -q; git config user.name "I.NR.D"; git config user.email "semkastler12@users.noreply.github.com"; }
git remote remove origin 2>/dev/null || true
git remote add origin "https://github.com/$OWNER/$REPO.git"
git add -A
git commit -q -m "Статья «Боковик: почему в него не надо лезть» + обложка 4:3" || echo "(изменений нет)"
git branch -M main
echo "файлов в коммите: $(git ls-files | wc -l), размер сайта: $(du -sh --exclude=.git . | cut -f1)"

echo
echo "== 4. Push =="
# Пуш идёт явным URL с токеном, БЕЗ -u: иначе git запишет токен в .git/config.
git -c credential.helper= push "https://$OWNER:${TOKEN}@github.com/$OWNER/$REPO.git" main:main --force
git config branch.main.remote origin
git config branch.main.merge refs/heads/main
echo "запушено (токен в .git/config: $(grep -c 'ghp_' .git/config || true) вхождений)"

echo
echo "== 5. Включение GitHub Pages =="
code=$(api -o /tmp/pub_pages.json -w '%{http_code}' -X POST "$API/repos/$OWNER/$REPO/pages" \
  -d '{"source":{"branch":"main","path":"/"}}')
case "$code" in
  201) echo "Pages включён" ;;
  409) echo "Pages уже был включён" ;;
  *)   echo "HTTP $code: $(cat /tmp/pub_pages.json | head -c 300)" ;;
esac

echo
echo "== 6. Ожидание публикации =="
URL="https://$OWNER.github.io/$REPO/"
for i in $(seq 1 40); do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$URL")
  printf '  попытка %2d: HTTP %s\n' "$i" "$code"
  [ "$code" = "200" ] && break
  sleep 10
done

echo
echo "== 7. Проверка результата =="
for u in "$URL" "${URL}img/01-5m-long-lumia.jpg" "${URL}img/cover-bokovik-4x3.png"; do
  curl -s -o /dev/null -w "  %{http_code}  %{size_download} байт  %{content_type}  $u\n" --max-time 25 "$u"
done
echo
echo "Сайт: $URL"
