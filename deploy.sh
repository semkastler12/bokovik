#!/usr/bin/env bash
# Публикация статьи на GitHub Pages.
#
#   ./deploy.sh                 → запушить в репозиторий по умолчанию (bokovik)
#   ./deploy.sh <имя-репозитория>
#   ./deploy.sh <владелец>/<репозиторий> [подпапка]
#
# Скрипт собирает index.html из статьи, коммитит и пушит в main.
set -euo pipefail
cd "$(dirname "$0")"

OWNER="semkastler12"
TARGET="${1:-bokovik}"
SUBDIR="${2:-}"
ARTICLE="bokovik-i-obem-pozicii.html"

if [[ "$TARGET" == */* ]]; then OWNER="${TARGET%%/*}"; REPO="${TARGET##*/}"; else REPO="$TARGET"; fi

if [ ! -f "$ARTICLE" ]; then echo "Нет файла $ARTICLE" >&2; exit 1; fi

# index.html — та же статья, чтобы корень сайта открывался сразу
cp -f "$ARTICLE" index.html
touch .nojekyll

if [ ! -d .git ]; then
  git init -q
  git config user.name  "I.NR.D"
  git config user.email "semkastler12@users.noreply.github.com"
  git remote add origin "https://github.com/$OWNER/$REPO.git"
fi
git add -A
git commit -q -m "Обложка и разбор 11 сделок" || echo "(нечего коммитить)"
git branch -M main

if [ -n "$SUBDIR" ]; then
  # заливка во вложенную папку чужого репозитория: subtree-ветка
  git subtree push --prefix . origin "refs/heads/$SUBDIR" 2>/dev/null || {
    echo "subtree не сработал, пушу веткой:"; git push -u origin main; }
else
  git push -u origin main
fi

echo
echo "Готово. Сайт появится на https://$OWNER.github.io/$REPO/${SUBDIR:+$SUBDIR/}"
