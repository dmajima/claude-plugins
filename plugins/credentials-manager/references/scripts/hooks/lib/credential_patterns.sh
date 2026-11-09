#!/usr/bin/env bash
# credential_patterns.sh
#
# credentials-manager の検出フック（PreToolUse の preempt_credentials_check.sh と
# UserPromptSubmit の detect_credentials_in_prompt.sh）が共有する、秘密情報のパターン定義。
# フックごとに定義すると検出範囲が食い違うため、ここで一元管理する。
# source して使う（単体では実行しない）。照合は bash の [[ =~ ]]（POSIX ERE）で行う。

# 既知のトークン形式。左側に境界を置き、単語の途中（task-management-system 等の語に含まれる部分）には一致させない
CRED_SECRET_PATTERN='(^|[^A-Za-z0-9_-])(sk-[A-Za-z0-9_-]{16,}|ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|ghu_[A-Za-z0-9]{20,}|ghs_[A-Za-z0-9]{20,}|ghr_[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|glpat-[A-Za-z0-9_-]{20,}|eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)'
CRED_BEARER_PATTERN='[Bb]earer[[:space:]]+[A-Za-z0-9._~+/=-]{16,}'
CRED_BASIC_PATTERN='[Bb]asic[[:space:]]+[A-Za-z0-9+/=]{16,}'
CRED_PEM_PATTERN='-----BEGIN[[:space:]]+(RSA[[:space:]]+|DSA[[:space:]]+|EC[[:space:]]+|OPENSSH[[:space:]]+|ENCRYPTED[[:space:]]+|PGP[[:space:]]+)?PRIVATE[[:space:]]+KEY-----'

# $1 の文字列に秘密情報らしいパターンがあれば 0 を返し、通知の理由文に使う語句を CRED_LABEL に入れる（無ければ 1）。
# 判定は既知のトークン形式 → Bearer → Basic → PEM の順で、最初に一致したものを採用する。
# サブシェルを起動しないよう、結果は変数で返す（フックはシェルの全呼び出しで動くため）
cred_find_secret() {
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
  [[ -n $CRED_LABEL ]]
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
