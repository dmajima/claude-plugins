#!/usr/bin/env bash
# credential_patterns.sh
#
# credentials-manager の検出フック（PreToolUse の preempt_credentials_check.sh と
# UserPromptSubmit の detect_credentials_in_prompt.sh）が共有する、秘密情報のパターン定義。
# フックごとに定義すると検出範囲が食い違うため、ここで一元管理する。
# source して使う（単体では実行しない）。照合は bash の [[ =~ ]]（POSIX ERE）で行う。

# 既知のトークン形式。左側に境界を置き、単語の途中（task-management-system 等の語に含まれる部分）には一致させない。
# 境界は、文字列の先頭・英数字と _ - 以外の文字に加え、エスケープした改行・タブ（\n \r \t、PowerShell の `n `r `t）と
# URL エンコード（%3D 等）の直後も含める（n や 3D は英数字のため、直前の 1 文字だけで判定すると
# printf 'a\n<トークン>'・"`n<トークン>"・%3D<トークン> のような書き方で検出されなくなる）
CRED_SECRET_PATTERN='(^|[^A-Za-z0-9_-]|\\[nrt]|`[nrt]|%[0-9A-Fa-f]{2})(sk-[A-Za-z0-9_-]{16,}|ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|ghu_[A-Za-z0-9]{20,}|ghs_[A-Za-z0-9]{20,}|ghr_[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|glpat-[A-Za-z0-9_-]{20,}|eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)'
CRED_BEARER_PATTERN='[Bb]earer[[:space:]]+[A-Za-z0-9._~+/=-]{16,}'
CRED_BASIC_PATTERN='[Bb]asic[[:space:]]+[A-Za-z0-9+/=]{16,}'
# PEM 形式の秘密鍵の先頭行。PGP の秘密鍵は、先頭行の KEY の後に BLOCK が続く
CRED_PEM_PATTERN='-----BEGIN[[:space:]]+(RSA[[:space:]]+|DSA[[:space:]]+|EC[[:space:]]+|OPENSSH[[:space:]]+|ENCRYPTED[[:space:]]+|PGP[[:space:]]+)?PRIVATE[[:space:]]+KEY([[:space:]]+BLOCK)?-----'

# bash の照合に掛ける文字列の長さの上限（256 KB）。bash の [[ =~ ]] は 1 MB あたり 0.5〜1 秒かかるため、
# これより長い文字列は grep でまとめて照合する（数 MB の書き込みやプロンプトで照合に timeout（10 秒）近くかかり、
# 通知が無言で欠落しないようにする。照合する範囲は削らない）
CRED_SCAN_MAX=262144

# $1 の文字列に秘密情報らしいパターンがあれば 0 を返し、通知の理由文に使う語句を CRED_LABEL に入れる（無ければ 1）。
# 判定は既知のトークン形式 → Bearer → Basic → PEM の順で、最初に一致したものを採用する。
# サブシェルを起動しないよう、結果は変数で返す（フックはシェルの全呼び出しで動くため）
cred_find_secret() {
  if (( ${#1} <= CRED_SCAN_MAX )); then
    cred_classify_secret "$1"
  else
    cred_find_secret_large "$1"
  fi
  [[ -n $CRED_LABEL ]]
}

# $1 を 4 種のパターンに順に照合し、最初に一致した種類の語句を CRED_LABEL に入れる（一致しなければ空）
cred_classify_secret() {
  CRED_LABEL=""
  if [[ $1 =~ $CRED_SECRET_PATTERN ]]; then
    CRED_LABEL='認証情報パターンを検出'
  elif [[ $1 =~ $CRED_BEARER_PATTERN ]]; then
    CRED_LABEL='Bearer トークンを検出'
  elif [[ $1 =~ $CRED_BASIC_PATTERN ]]; then
    CRED_LABEL='Basic 認証ヘッダらしい文字列を検出'
  elif [[ $1 =~ $CRED_PEM_PATTERN ]]; then
    CRED_LABEL='PEM 形式の秘密鍵を検出'
  fi
}

# CRED_SCAN_MAX を超える文字列の照合（cred_find_secret から呼ぶ）。4 種をまとめて grep で 1 回照合し、
# 一致した部分（先頭 4 KB まで）を cred_classify_secret に掛けて種類を決める。一致した部分は変数に置くだけで出力しない。
# grep は行ごとに照合するため、改行を空白に置き換えてから渡す（パターンは改行と空白を同じに扱うため、結果は bash の照合と変わらない）。
# 入力はヒアストリングで渡す（printf でパイプに書くと、改行の多い入力では 1 行ずつ書き込まれて数秒かかる）
cred_find_secret_large() {
  local hit
  hit="$(LC_ALL=C tr '\r\n' '  ' <<< "$1" | LC_ALL=C grep -aoE -- "$CRED_SECRET_PATTERN|$CRED_BEARER_PATTERN|$CRED_BASIC_PATTERN|$CRED_PEM_PATTERN" 2>/dev/null | head -c 4096)"
  cred_classify_secret "$hit"
  # 一致した部分が 4 KB で切れて種類を決められない場合（Bearer の後に空白が 4 KB 以上続く等）も、一致はしているため通知する
  if [[ -n $hit && -z $CRED_LABEL ]]; then
    CRED_LABEL='認証情報パターンを検出'
  fi
}

# 通知の理由文を CRED_REASON に組み立てる: $1（「Bash コマンドに」等）+ CRED_LABEL。
# 英字で始まる語句（Bearer 等）の前には空白を入れ、既存の文言の体裁（「コマンドに Bearer トークンを検出」）に合わせる
cred_reason() {
  if [[ $CRED_LABEL == [A-Za-z]* ]]; then
    CRED_REASON="$1 $CRED_LABEL"
  else
    CRED_REASON="$1$CRED_LABEL"
  fi
}
