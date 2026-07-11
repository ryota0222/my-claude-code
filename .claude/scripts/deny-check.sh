#!/bin/bash
#
# --dangerously-skip-permissions 使用時の安全網 (PreToolUse フック)。
# settings.json の deny リスト(Bash パターン)と照合し、危険コマンドを exit 2 でブロックする。
#
# 設計方針:
#   - fail-closed: 判定に必要な情報が欠けたら「安全側=ブロック」に倒す。
#   - 難読化耐性: パイプ/バックグラウンド/コマンド置換/サブシェル等で境界を跨いだ
#     コマンドも分解し、先頭の env 代入・ラッパー・パスを正規化してから照合する。
#   - macOS 標準の bash 3.2 互換 (連想配列などの 4.x 機能は使わない)。
#
# 注意: 文字列近似マッチである以上、完全な防御は原理的に不可能。過信しないこと。

set -f  # パス名展開(グロブ)を無効化。未クオート展開でのファイル名混入を防ぐ。
        # [[ str == pat ]] のパターン照合は set -f の影響を受けないので照合は従来通り動く。

settings_file="$HOME/.claude/settings.json"

# --- 入力取得 (jq 必須。無ければ fail-closed) ------------------------------
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq が見つからないため安全のためブロックしました。" >&2
  exit 2
fi

input=$(cat)
tool_name=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)

# Bash 以外のツールは対象外
[ "$tool_name" != "Bash" ] && exit 0

command=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)

# コマンドが空(取得失敗含む)なら実行しても無害なので素通り
[ -z "$command" ] && exit 0

# --- deny パターン抽出 ------------------------------------------------------
deny_patterns=$(jq -r '
  .permissions.deny[]?
  | select(type=="string")
  | select(startswith("Bash("))
  | ltrimstr("Bash(")
  | rtrimstr(")")
' "$settings_file" 2>/dev/null)

# パターンを読めなかったら安全側でブロック
if [ -z "$deny_patterns" ]; then
  echo "Error: deny パターンを読み込めなかったため安全のためブロックしました。" >&2
  exit 2
fi

home_real="$HOME"

# --- 正規化ヘルパ -----------------------------------------------------------

# 空白(タブ/改行含む)を単一スペースに畳み、前後をトリムする
normalize_ws() {
  local s="$1"
  s="${s//$'\t'/ }"
  s="${s//$'\n'/ }"
  while [[ "$s" == *"  "* ]]; do s="${s//  / }"; done
  s="${s#"${s%%[![:space:]]*}"}"   # 先頭空白除去
  s="${s%"${s##*[![:space:]]}"}"   # 末尾空白除去
  printf '%s' "$s"
}

# ホームディレクトリ表記を ~ に、"./"(カレント相対) を除去して正規化する
# → "* ~/.ssh/*" や "* .env*" のような部分一致パターンを取りこぼさないため
normalize_path() {
  local s="$1"
  [ -n "$home_real" ] && s="${s//$home_real/~}"
  s="${s//\$\{HOME\}/~}"
  s="${s//\$HOME/~}"
  s="${s// .\// }"     # " ./foo" → " foo"
  printf '%s' "$s"
}

# 安全なテンプレート系 env ファイル名を無害化して "* .env*" の誤検知を防ぐ。
# 「.env で始まり .example/.sample/.template/.dist で終わる」トークンだけを対象に
# 先頭の "." を外し、"* .env*" に当たらないようにする。
# 例: cat .env.example / .env.local.example → 許可。
#     一方 cp .env.example .env は本物の .env トークンが残るため引き続きブロック。
neutralize_safe_env() {
  local s="$1" tok core result="" IFS=' '
  for tok in $s; do            # set -f 済みなのでグロブ展開は起きない
    core="$tok"
    # 末尾に付いたクォート/区切り記号を剥がして拡張子判定する
    core="${core%[\'\"\`\;\,]}"
    core="${core%[\'\"\`\;\,]}"
    case "$core" in
      .env*.example|.env*.sample|.env*.template|.env*.dist)
        tok="env${tok#.env}"   # 先頭の "." を外す (.env.local.example → env.local.example)
        ;;
    esac
    if [ -z "$result" ]; then result="$tok"; else result="$result $tok"; fi
  done
  printf '%s' "$result"
}

# セグメント先頭のノイズ(env 代入 / ラッパーコマンド / バックスラッシュ)を剥がす
# 例: FOO=bar rm ... → rm ... / command rm ... → rm ... / \rm → rm
strip_prefix() {
  local s="$1" first rest
  while :; do
    if [[ "$s" =~ ^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+(.*)$ ]]; then
      s="${BASH_REMATCH[1]}"
      continue
    fi
    first="${s%%[[:space:]]*}"
    case "$first" in
      command|builtin|exec|eval|nohup|time|env)
        rest="${s#"$first"}"
        rest="${rest#"${rest%%[![:space:]]*}"}"   # 続く空白を除去
        [ -z "$rest" ] && break
        s="$rest"
        ;;
      \\*)
        s="${s#\\}"
        ;;
      *)
        break
        ;;
    esac
  done
  printf '%s' "$s"
}

# --- worktree 例外 (削除系コマンドの限定許可) ------------------------------

# cwd がリンク worktree なら、その worktree ルートを出力する。
# メイン作業ツリー / 非 git / git 不在 なら何も出さず失敗を返す(=例外なし)。
worktree_root() {
  local d="$1" gdir top
  [ -n "$d" ] && [ -d "$d" ] || return 1
  command -v git >/dev/null 2>&1 || return 1
  gdir=$(git -C "$d" rev-parse --absolute-git-dir 2>/dev/null) || return 1
  # リンク worktree の git-dir は <main>/.git/worktrees/<name> の形になる。
  # メイン作業ツリー(<repo>/.git)や submodule はこの形にならないので誤検出しない。
  case "$gdir" in
    */.git/worktrees/*) ;;
    *) return 1 ;;
  esac
  top=$(git -C "$d" rev-parse --show-toplevel 2>/dev/null) || return 1
  [ -n "$top" ] || return 1
  printf '%s' "$top"
}

# セグメント先頭コマンドが削除系(rm/rmdir/unlink)か
seg_is_rm_family() {
  local first="${1%%[[:space:]]*}"
  first="${first##*/}"                 # basename (/usr/bin/rm → rm)
  case "$first" in
    rm|rmdir|unlink) return 0 ;;
    *) return 1 ;;
  esac
}

# deny パターンが削除系(rm/rmdir/unlink)か
is_rm_family_pattern() {
  local first="${1%%[[:space:]]*}"
  first="${first%)}"
  first="${first##*/}"
  case "$first" in
    rm|rmdir|unlink) return 0 ;;
    *) return 1 ;;
  esac
}

# rm 系セグメントの削除対象がすべて worktree 配下に収まるか判定する。
# 外部の絶対パス / ".." / "~" / 変数・コマンド置換($ `) を含むなら
# 「収まらない」とみなして失敗(=1)を返す(保守的に外部扱い)。
rm_targets_confined() {
  local cmd="$1" wt="$2" tok IFS=' '
  set -- $cmd                          # set -f 済みなのでグロブ展開は起きない
  shift                                # コマンド名(rm 等)を除去
  for tok in "$@"; do
    case "$tok" in
      -*) continue ;;                  # オプションフラグは対象外
    esac
    case "$tok" in
      *'$'*|*'`'*) return 1 ;;         # 変数/コマンド置換 → 不確定なので拒否
      *..*)        return 1 ;;         # 上位ディレクトリ参照
      '~'|'~/'*)   return 1 ;;         # ホーム = worktree 外
      /*)
        case "$tok" in
          "$wt"|"$wt"/*) : ;;          # worktree 配下の絶対パス → OK
          *) return 1 ;;               # 外部の絶対パス
        esac
        ;;
    esac
  done
  return 0
}

# cwd がリンク worktree なら削除系を「楽観的に許可」し、
# 非 confine な rm 系セグメントを見つけた時点で許可を取り消す。
# ※ bypassPermissions(--dangerously-skip-permissions)時のみ実効。
#    通常モードでは settings.json の native deny が別途効くため挙動は変わらない。
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
wt_root=$(worktree_root "$cwd")
rm_exempt=0
[ -n "$wt_root" ] && rm_exempt=1

# --- 照合対象(候補)の生成 --------------------------------------------------
# candidates 配列に、照合すべき文字列を積んでいく。多めに積んでも
# 「ブロックが増える」方向にしか働かず、素通り(bypass)は生まない。
candidates=()

# (1) コマンド全文: 部分一致パターン(* .env* / * ~/.ssh/* 等)を捕捉
full=$(normalize_ws "$command")
candidates+=("$full")
full_norm=$(normalize_path "$full")
[ "$full_norm" != "$full" ] && candidates+=("$full_norm")

# (2) セグメント分割: コマンド境界になり得る記号を改行に置換して分割
#     ; & | ( ) { } < > ` および改行 (&& / || は & / | の単字置換で分割される)
seg_src="$command"
for ch in ';' '&' '|' '(' ')' '{' '}' '<' '>' '`' $'\n'; do
  seg_src="${seg_src//"$ch"/$'\n'}"
done

while IFS= read -r seg; do
  seg=$(normalize_ws "$seg")
  [ -z "$seg" ] && continue
  candidates+=("$seg")                       # 素の(先頭未処理)セグメント

  stripped=$(strip_prefix "$seg")
  stripped=$(normalize_ws "$stripped")
  [ -z "$stripped" ] && continue
  [ "$stripped" != "$seg" ] && candidates+=("$stripped")

  # worktree 例外: rm 系セグメントが worktree 外を消そうとしていたら許可を取り消す
  if [ "$rm_exempt" = "1" ] && seg_is_rm_family "$stripped"; then
    rm_targets_confined "$stripped" "$wt_root" || rm_exempt=0
  fi

  # 先頭トークンがパスを含むなら basename 版も (/usr/local/bin/rm → rm)
  first="${stripped%%[[:space:]]*}"
  if [[ "$first" == */* ]]; then
    base="${first##*/}"
    rest="${stripped#"$first"}"
    candidates+=("$base$rest")
  fi

  # ホーム/相対パス正規化版
  seg_norm=$(normalize_path "$stripped")
  [ "$seg_norm" != "$stripped" ] && candidates+=("$seg_norm")
done <<< "$seg_src"

# --- 照合 -------------------------------------------------------------------
match_pattern() {
  local cand="$1" pattern scan
  scan=$(neutralize_safe_env "$cand")        # .env.example 等の安全名を無害化
  while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    if [[ "$scan" == $pattern ]]; then       # $pattern は未クオート = グロブ照合
      # worktree 例外が有効なら、削除系(rm/rmdir/unlink)パターンは無視して次へ。
      # 非削除系パターン(curl/ssh 等)は例外に関係なくブロックする。
      if [ "$rm_exempt" = "1" ] && is_rm_family_pattern "$pattern"; then
        continue
      fi
      printf '%s' "$pattern"
      return 0
    fi
  done <<< "$deny_patterns"
  return 1
}

for cand in "${candidates[@]}"; do
  [ -z "$cand" ] && continue
  if pat=$(match_pattern "$cand"); then
    echo "Error: コマンドが拒否されました: '$cand' (パターン: '$pat')" >&2
    exit 2
  fi
done

exit 0
